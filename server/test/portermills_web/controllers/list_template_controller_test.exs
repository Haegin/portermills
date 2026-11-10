defmodule PortermillsWeb.ListTemplateControllerTest do
  use PortermillsWeb.ConnCase, async: true

  alias Portermills.Lists

  setup :two_families

  test "create, read, update and delete a template", %{conn: conn, user: user} do
    conn = authed(conn, user)

    created = conn |> post("/api/list-templates", %{name: "Beach", items: ["Towels", "Suncream"]}) |> json_response(201)
    assert %{"name" => "Beach", "items" => [%{"name" => "Towels", "position" => 1}, %{"name" => "Suncream"}]} = created
    id = created["id"]

    assert [%{"id" => ^id}] = conn |> get("/api/list-templates") |> json_response(200)
    assert %{"id" => ^id} = conn |> get("/api/list-templates/#{id}") |> json_response(200)

    assert %{"name" => "Seaside", "items" => [%{"name" => "Bucket"}]} =
             conn |> patch("/api/list-templates/#{id}", %{name: "Seaside", items: ["Bucket"]}) |> json_response(200)

    assert conn |> delete("/api/list-templates/#{id}") |> response(204)
    assert conn |> get("/api/list-templates") |> json_response(200) == []
  end

  test "a template can be saved from a list", %{conn: conn, user: user, family: family} do
    list = list_fixture(family, %{type: :packing, name: "Festival"})
    list_item_fixture(list, user, %{name: "Wellies"})

    assert %{"name" => "Festival kit", "items" => [%{"name" => "Wellies"}]} =
             conn
             |> authed(user)
             |> post("/api/list-templates", %{from_list_id: list.id, name: "Festival kit"})
             |> json_response(201)
  end

  test "changes are broadcast to the family's lists topic", %{conn: conn, user: user} do
    PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:lists")
    %{"id" => id} = conn |> authed(user) |> post("/api/list-templates", %{name: "Beach"}) |> json_response(201)
    assert_receive %Phoenix.Socket.Broadcast{event: "template:changed", payload: %{id: ^id}}
  end

  test "another family can't read, change, delete or copy from it", %{conn: conn, family: family, stranger: stranger} do
    template = template_fixture(family)
    list = list_fixture(family)
    conn = authed(conn, stranger)

    assert conn |> get("/api/list-templates") |> json_response(200) == []
    assert conn |> get("/api/list-templates/#{template.id}") |> json_response(404)
    assert conn |> patch("/api/list-templates/#{template.id}", %{name: "Hacked"}) |> json_response(404)
    assert conn |> delete("/api/list-templates/#{template.id}") |> json_response(404)
    assert conn |> post("/api/list-templates", %{from_list_id: list.id}) |> json_response(404)

    assert Lists.get_template(family.id, template.id).name == "Camping"
  end
end
