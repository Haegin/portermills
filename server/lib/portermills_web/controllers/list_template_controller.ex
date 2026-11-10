defmodule PortermillsWeb.ListTemplateController do
  use PortermillsWeb, :controller

  alias Portermills.Lists
  alias Portermills.Lists.{List, Template}
  alias PortermillsWeb.ListJSON

  def index(conn, _params) do
    templates = Lists.list_templates(conn.assigns.current_user.family_id)
    json(conn, Enum.map(templates, &ListJSON.template/1))
  end

  def show(conn, %{"id" => id}) do
    with %Template{} = template <- Lists.get_template(conn.assigns.current_user.family_id, id) do
      json(conn, ListJSON.template(template))
    end
  end

  # With a `from_list_id`, saves that list's current items as the template.
  def create(conn, %{"from_list_id" => list_id} = params) when is_binary(list_id) do
    with %List{} = list <- Lists.get_list(conn.assigns.current_user.family_id, list_id),
         {:ok, template} <- Lists.create_template_from_list(list, params) do
      created(conn, template)
    end
  end

  def create(conn, params) do
    with {:ok, template} <- Lists.create_template(conn.assigns.current_user.family_id, params) do
      created(conn, template)
    end
  end

  defp created(conn, template) do
    Broadcast.lists(template.family_id, "template:changed", %{id: template.id})
    conn |> put_status(:created) |> json(ListJSON.template(template))
  end

  def update(conn, %{"id" => id} = params) do
    family_id = conn.assigns.current_user.family_id

    with %Template{} = template <- Lists.get_template(family_id, id),
         {:ok, template} <- Lists.update_template(template, params) do
      Broadcast.lists(family_id, "template:changed", %{id: template.id})
      json(conn, ListJSON.template(template))
    end
  end

  def delete(conn, %{"id" => id}) do
    family_id = conn.assigns.current_user.family_id

    with %Template{} = template <- Lists.get_template(family_id, id),
         {:ok, _} <- Lists.delete_template(template) do
      Broadcast.lists(family_id, "template:changed", %{id: template.id})
      send_resp(conn, :no_content, "")
    end
  end
end
