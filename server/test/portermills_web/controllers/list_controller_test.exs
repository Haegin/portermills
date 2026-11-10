defmodule PortermillsWeb.ListControllerTest do
  use PortermillsWeb.ConnCase, async: true

  alias Portermills.Lists

  setup :two_families

  test "create, read, rename and delete a list", %{conn: conn, user: user} do
    conn = authed(conn, user)

    created = conn |> post("/api/lists", %{type: "packing", name: "Skiing"}) |> json_response(201)
    assert %{"type" => "packing", "name" => "Skiing", "item_count" => 0, "checked_count" => 0} = created
    assert created["family_id"] == user.family_id
    id = created["id"]

    assert [%{"id" => ^id}] = conn |> get("/api/lists") |> json_response(200)
    assert %{"id" => ^id, "items" => []} = conn |> get("/api/lists/#{id}") |> json_response(200)
    assert %{"name" => "Ski trip"} = conn |> patch("/api/lists/#{id}", %{name: "Ski trip"}) |> json_response(200)

    assert conn |> delete("/api/lists/#{id}") |> response(204)
    assert conn |> get("/api/lists") |> json_response(200) == []
  end

  test "an invalid list is rejected", %{conn: conn, user: user} do
    assert %{"errors" => %{"name" => _}} =
             conn |> authed(user) |> post("/api/lists", %{type: "shopping"}) |> json_response(422)
  end

  test "a packing list can be created from a template", %{conn: conn, user: user, family: family} do
    template = template_fixture(family)
    conn = authed(conn, user)

    created = conn |> post("/api/lists", %{template_id: template.id, name: "Lakes"}) |> json_response(201)
    assert %{"type" => "packing", "name" => "Lakes", "item_count" => 2} = created

    assert %{"items" => [%{"name" => "Tent", "checked" => false}, %{"name" => "Stove"}]} =
             conn |> get("/api/lists/#{created["id"]}") |> json_response(200)
  end

  test "another family's template can't be used", %{conn: conn, stranger: stranger, family: family} do
    template = template_fixture(family)
    assert conn |> authed(stranger) |> post("/api/lists", %{template_id: template.id}) |> json_response(404)
    assert Lists.list_lists(stranger.family_id) == []
  end

  test "writes are broadcast to the family's lists topic", %{conn: conn, user: user} do
    PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:lists")
    conn = authed(conn, user)

    %{"id" => id} = conn |> post("/api/lists", %{type: "shopping", name: "Shop"}) |> json_response(201)
    assert_receive %Phoenix.Socket.Broadcast{event: "list:created", payload: %{list: %{id: ^id}}}

    patch(conn, "/api/lists/#{id}", %{name: "Big shop"})
    assert_receive %Phoenix.Socket.Broadcast{event: "list:updated", payload: %{list: %{name: "Big shop"}}}

    delete(conn, "/api/lists/#{id}")
    assert_receive %Phoenix.Socket.Broadcast{event: "list:deleted", payload: %{id: ^id}}
  end

  test "another family can't read, change or delete the list", %{conn: conn, family: family, stranger: stranger} do
    list = list_fixture(family)
    conn = authed(conn, stranger)

    assert conn |> get("/api/lists") |> json_response(200) == []
    assert conn |> get("/api/lists/#{list.id}") |> json_response(404)
    assert conn |> patch("/api/lists/#{list.id}", %{name: "Hacked"}) |> json_response(404)
    assert conn |> delete("/api/lists/#{list.id}") |> json_response(404)

    assert Lists.get_list(family.id, list.id).name == "Shopping"
  end
end
