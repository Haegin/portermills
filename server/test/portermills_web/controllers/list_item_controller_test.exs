defmodule PortermillsWeb.ListItemControllerTest do
  use PortermillsWeb.ConnCase, async: true

  alias Portermills.Lists

  setup :two_families

  setup %{family: family} do
    %{list: list_fixture(family)}
  end

  test "add, tick, rename and delete an item", %{conn: conn, user: user, list: list} do
    conn = authed(conn, user)
    base = "/api/lists/#{list.id}/items"

    item = conn |> post(base, %{name: "Milk"}) |> json_response(201)
    assert %{"name" => "Milk", "checked" => false, "position" => 1} = item
    assert item["added_by_id"] == user.id
    assert item["list_id"] == list.id

    assert %{"checked" => true} = conn |> patch("#{base}/#{item["id"]}", %{checked: true}) |> json_response(200)
    assert %{"name" => "Oat milk"} = conn |> patch("#{base}/#{item["id"]}", %{name: "Oat milk"}) |> json_response(200)
    assert [%{"name" => "Oat milk", "checked" => true}] = conn |> get(base) |> json_response(200)

    assert conn |> delete("#{base}/#{item["id"]}") |> response(204)
    assert conn |> get(base) |> json_response(200) == []
  end

  test "an item needs a name", %{conn: conn, user: user, list: list} do
    assert %{"errors" => %{"name" => _}} =
             conn |> authed(user) |> post("/api/lists/#{list.id}/items", %{}) |> json_response(422)
  end

  test "writes are broadcast to the family's lists topic", %{conn: conn, user: user, list: list} do
    PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:lists")
    conn = authed(conn, user)
    base = "/api/lists/#{list.id}/items"
    list_id = list.id

    %{"id" => id} = conn |> post(base, %{name: "Milk"}) |> json_response(201)
    assert_receive %Phoenix.Socket.Broadcast{event: "list:item_added", payload: %{item: %{id: ^id, list_id: ^list_id}}}

    patch(conn, "#{base}/#{id}", %{checked: true})
    assert_receive %Phoenix.Socket.Broadcast{event: "list:item_updated", payload: %{item: %{id: ^id, checked: true}}}

    delete(conn, "#{base}/#{id}")
    assert_receive %Phoenix.Socket.Broadcast{event: "list:item_deleted", payload: %{id: ^id, list_id: ^list_id}}
  end

  test "another family can't read or change the items", %{conn: conn, user: user, stranger: stranger, list: list} do
    item = list_item_fixture(list, user)
    conn = authed(conn, stranger)
    base = "/api/lists/#{list.id}/items"

    assert conn |> get(base) |> json_response(404)
    assert conn |> post(base, %{name: "Sneaky"}) |> json_response(404)
    assert conn |> patch("#{base}/#{item.id}", %{checked: true}) |> json_response(404)
    assert conn |> delete("#{base}/#{item.id}") |> json_response(404)

    assert [%{name: "Milk", checked: false}] = Lists.list_items(list)
  end

  test "an item can't be reached through another family's own list", %{conn: conn, user: user, stranger: stranger, list: list} do
    item = list_item_fixture(list, user)
    {:ok, their_list} = Lists.create_list(stranger.family_id, %{type: :shopping, name: "Theirs"})

    conn = authed(conn, stranger)
    assert conn |> patch("/api/lists/#{their_list.id}/items/#{item.id}", %{checked: true}) |> json_response(404)
    assert conn |> delete("/api/lists/#{their_list.id}/items/#{item.id}") |> json_response(404)
    assert [%{checked: false}] = Lists.list_items(list)
  end
end
