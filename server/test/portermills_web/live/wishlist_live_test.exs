defmodule PortermillsWeb.WishlistLiveTest do
  use PortermillsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Portermills.Wishlists

  setup do
    family = family_fixture()
    owner = user_fixture(family, %{name: "Alex"})
    giver = user_fixture(family, %{name: "Sam"})
    wishlist = owner |> wishlist_fixture() |> Wishlists.ensure_share_token()
    %{owner: owner, giver: giver, wishlist: wishlist}
  end

  test "shows the shared wishlist without any claim data", %{conn: conn, wishlist: wishlist, giver: giver} do
    item = wishlist_item_fixture(wishlist, %{name: "Bike", price: "349.99", url: "https://example.com/bike"})
    {:ok, _} = Wishlists.claim_item(wishlist, item, giver)

    {:ok, _view, html} = live(conn, "/wishlists/#{wishlist.share_token}")

    assert html =~ "Alex&#39;s wishlist"
    assert html =~ "Bike"
    assert html =~ "£349.99"
    assert html =~ "https://example.com/bike"
    refute html =~ "laim"
    refute html =~ "Sam"
  end

  test "doesn't link unsafe URLs", %{conn: conn, wishlist: wishlist} do
    wishlist_item_fixture(wishlist, %{name: "Trap", url: "javascript:alert(1)"})
    {:ok, _view, html} = live(conn, "/wishlists/#{wishlist.share_token}")
    refute html =~ "javascript:"
  end

  test "updates live when an item is added", %{conn: conn, owner: owner, wishlist: wishlist} do
    {:ok, view, html} = live(conn, "/wishlists/#{wishlist.share_token}")
    assert html =~ "Nothing on the list yet."

    build_conn()
    |> authed(owner)
    |> post("/api/wishlists/#{wishlist.id}/items", %{name: "Telescope"})
    |> json_response(201)

    assert render(view) =~ "Telescope"
  end

  test "is not reachable by wishlist id or a wrong token", %{conn: conn, wishlist: wishlist} do
    assert_error_sent 404, fn -> get(conn, "/wishlists/#{wishlist.id}") end
    assert_error_sent 404, fn -> get(conn, "/wishlists/nope") end
  end
end
