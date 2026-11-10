defmodule PortermillsWeb.WishlistControllerTest do
  use PortermillsWeb.ConnCase, async: true

  alias Portermills.Wishlists

  setup :two_families

  setup %{user: user} do
    wishlist = wishlist_fixture(user)
    %{wishlist: wishlist, item: wishlist_item_fixture(wishlist, %{name: "Bike", price: "349.99", priority: :high})}
  end

  describe "wishlists" do
    test "index lists one per family member, flagging the caller's own", %{conn: conn, user: user} do
      body = conn |> authed(user) |> get("/api/wishlists") |> json_response(200)

      assert [
               %{"is_mine" => true, "item_count" => 1, "user" => %{"name" => "Alex"}},
               %{"is_mine" => false, "item_count" => 0, "user" => %{"name" => "Sam"}}
             ] = body
    end

    test "the owner can hide their wishlist from the family", %{conn: conn, user: user, other: other, wishlist: wishlist} do
      assert %{"is_visible_to_family" => false} =
               conn |> authed(user) |> patch("/api/wishlists/#{wishlist.id}", %{is_visible_to_family: false}) |> json_response(200)

      assert build_conn() |> authed(other) |> get("/api/wishlists/#{wishlist.id}") |> json_response(404)
      assert build_conn() |> authed(user) |> get("/api/wishlists/#{wishlist.id}") |> json_response(200)
    end

    test "only the owner can change or share a wishlist", %{conn: conn, other: other, wishlist: wishlist} do
      conn = authed(conn, other)
      assert conn |> patch("/api/wishlists/#{wishlist.id}", %{is_visible_to_family: false}) |> json_response(403)
      assert conn |> post("/api/wishlists/#{wishlist.id}/share") |> json_response(403)
      assert conn |> delete("/api/wishlists/#{wishlist.id}/share") |> json_response(403)
    end

    test "the owner can turn the public page on and off", %{conn: conn, user: user, wishlist: wishlist} do
      conn = authed(conn, user)
      assert %{"url" => url} = conn |> post("/api/wishlists/#{wishlist.id}/share") |> json_response(200)
      path = URI.parse(url).path
      assert html_response(get(build_conn(), path), 200) =~ "Bike"

      assert conn |> delete("/api/wishlists/#{wishlist.id}/share") |> response(204)
      assert_error_sent 404, fn -> get(build_conn(), path) end
    end
  end

  describe "items" do
    test "the owner can add, edit and delete items", %{conn: conn, user: user, wishlist: wishlist} do
      conn = authed(conn, user)
      base = "/api/wishlists/#{wishlist.id}/items"

      created = conn |> post(base, %{name: "Headphones", url: "https://example.com/h", notes: "Over-ear", price: "89.5", priority: "low"}) |> json_response(201)
      assert %{"name" => "Headphones", "price" => "89.5", "priority" => "low", "notes" => "Over-ear"} = created

      assert %{"name" => "Earbuds"} = conn |> patch("#{base}/#{created["id"]}", %{name: "Earbuds"}) |> json_response(200)
      assert %{"name" => "Earbuds"} = conn |> get("#{base}/#{created["id"]}") |> json_response(200)
      assert conn |> delete("#{base}/#{created["id"]}") |> response(204)
      assert [%{"name" => "Bike"}] = conn |> get(base) |> json_response(200)
    end

    test "other family members can't add, edit or delete", %{conn: conn, other: other, wishlist: wishlist, item: item} do
      conn = authed(conn, other)
      base = "/api/wishlists/#{wishlist.id}/items"

      assert conn |> post(base, %{name: "Sneaky"}) |> json_response(403)
      assert conn |> patch("#{base}/#{item.id}", %{name: "Sneaky"}) |> json_response(403)
      assert conn |> delete("#{base}/#{item.id}") |> json_response(403)
    end

    test "item changes are broadcast with ids only", %{conn: conn, user: user, wishlist: wishlist} do
      PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:wishlists")
      conn |> authed(user) |> post("/api/wishlists/#{wishlist.id}/items", %{name: "Hat"}) |> json_response(201)

      wishlist_id = wishlist.id
      assert_receive %Phoenix.Socket.Broadcast{event: "wishlist:updated", payload: payload}
      assert payload == %{wishlist_id: wishlist_id}
    end
  end

  describe "claims" do
    test "a family member claims and releases an item", %{conn: conn, other: other, wishlist: wishlist, item: item} do
      conn = authed(conn, other)

      assert %{"is_claimed" => false, "claimed_by_me" => false} =
               conn |> get("/api/wishlists/#{wishlist.id}/items/#{item.id}") |> json_response(200)

      assert %{"is_claimed" => true, "claimed_by_me" => true, "claimed_by_name" => "Sam"} =
               conn |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(200)

      assert [%{"is_claimed" => true}] = conn |> get("/api/wishlists/#{wishlist.id}/items") |> json_response(200)

      assert %{"is_claimed" => false, "claimed_by_me" => false} =
               conn |> delete("/api/wishlists/items/#{item.id}/claim") |> json_response(200)
    end

    test "a claimed item can't be claimed again", %{conn: conn, family: family, other: other, item: item} do
      third = user_fixture(family, %{name: "Jo"})
      conn |> authed(other) |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(200)

      assert build_conn() |> authed(third) |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(409)

      # …and a third person sees it as claimed, but not by them.
      assert %{"is_claimed" => true, "claimed_by_me" => false, "claimed_by_name" => "Sam"} =
               build_conn() |> authed(third) |> get("/api/wishlists/#{item.wishlist_id}/items/#{item.id}") |> json_response(200)
    end

    test "the owner cannot see claims on their own wishlist", %{conn: conn, user: user, other: other, wishlist: wishlist, item: item} do
      build_conn() |> authed(other) |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(200)
      conn = authed(conn, user)

      responses = [
        conn |> get("/api/wishlists") |> response(200),
        conn |> get("/api/wishlists/#{wishlist.id}") |> response(200),
        conn |> get("/api/wishlists/#{wishlist.id}/items") |> response(200),
        conn |> get("/api/wishlists/#{wishlist.id}/items/#{item.id}") |> response(200),
        conn |> patch("/api/wishlists/#{wishlist.id}/items/#{item.id}", %{notes: "Any colour"}) |> response(200)
      ]

      for body <- responses do
        refute body =~ "claim"
      end

      # Nothing about the wishlist itself names the person who claimed.
      for body <- tl(responses), do: refute(body =~ other.id)

      [owner_item] = conn |> get("/api/wishlists/#{wishlist.id}/items") |> json_response(200)
      refute Map.has_key?(owner_item, "is_claimed")
      refute Map.has_key?(owner_item, "claimed_by_me")
      refute Map.has_key?(owner_item, "claimed_by_name")
    end

    test "the owner cannot claim or release on their own wishlist", %{conn: conn, user: user, other: other, item: item} do
      conn = authed(conn, user)
      assert conn |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(403)

      build_conn() |> authed(other) |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(200)
      refuted = conn |> delete("/api/wishlists/items/#{item.id}/claim")
      assert json_response(refuted, 403)
      refute refuted.resp_body =~ "claimed_by"
      assert Portermills.Repo.aggregate(Wishlists.Claim, :count) == 1
    end

    test "claim broadcasts carry no claim details", %{conn: conn, user: user, other: other, wishlist: wishlist, item: item} do
      PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:wishlists")
      conn |> authed(other) |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(200)

      assert_receive %Phoenix.Socket.Broadcast{event: "wishlist:claims_changed", payload: payload}
      # owner_id is consumed by FamilyChannel to withhold the event from the owner.
      assert payload == %{wishlist_id: wishlist.id, owner_id: user.id}
    end
  end

  describe "another family" do
    test "can't see or touch anything", %{conn: conn, stranger: stranger, wishlist: wishlist, item: item} do
      conn = authed(conn, stranger)
      base = "/api/wishlists/#{wishlist.id}"

      ids = conn |> get("/api/wishlists") |> json_response(200) |> Enum.map(& &1["id"])
      refute wishlist.id in ids

      assert conn |> get(base) |> json_response(404)
      assert conn |> patch(base, %{is_visible_to_family: false}) |> json_response(404)
      assert conn |> post("#{base}/share") |> json_response(404)
      assert conn |> get("#{base}/items") |> json_response(404)
      assert conn |> get("#{base}/items/#{item.id}") |> json_response(404)
      assert conn |> post("#{base}/items", %{name: "Sneaky"}) |> json_response(404)
      assert conn |> patch("#{base}/items/#{item.id}", %{name: "Sneaky"}) |> json_response(404)
      assert conn |> delete("#{base}/items/#{item.id}") |> json_response(404)
      assert conn |> post("/api/wishlists/items/#{item.id}/claim") |> json_response(404)
      assert conn |> delete("/api/wishlists/items/#{item.id}/claim") |> json_response(404)

      assert Portermills.Repo.aggregate(Wishlists.Claim, :count) == 0
    end
  end
end
