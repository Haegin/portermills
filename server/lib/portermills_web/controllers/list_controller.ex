defmodule PortermillsWeb.ListController do
  use PortermillsWeb, :controller

  alias Portermills.Lists
  alias Portermills.Lists.{List, Template}
  alias PortermillsWeb.ListJSON

  def index(conn, _params) do
    lists = Lists.list_lists(conn.assigns.current_user.family_id)
    json(conn, Enum.map(lists, &ListJSON.list/1))
  end

  def show(conn, %{"id" => id}) do
    with %List{} = list <- Lists.get_list(conn.assigns.current_user.family_id, id) do
      items = Lists.list_items(list)
      json(conn, Map.put(ListJSON.list(list), :items, Enum.map(items, &ListJSON.item/1)))
    end
  end

  # With a `template_id`, creates a packing list pre-filled from that template.
  def create(conn, %{"template_id" => template_id} = params) when is_binary(template_id) do
    user = conn.assigns.current_user

    with %Template{} = template <- Lists.get_template(user.family_id, template_id),
         {:ok, list} <- Lists.create_list_from_template(template, user.id, params) do
      created(conn, list)
    end
  end

  def create(conn, params) do
    with {:ok, list} <- Lists.create_list(conn.assigns.current_user.family_id, params) do
      created(conn, list)
    end
  end

  defp created(conn, list) do
    Broadcast.lists(list.family_id, "list:created", %{list: ListJSON.list(list)})
    conn |> put_status(:created) |> json(ListJSON.list(list))
  end

  def update(conn, %{"id" => id} = params) do
    family_id = conn.assigns.current_user.family_id

    with %List{} = list <- Lists.get_list(family_id, id),
         {:ok, list} <- Lists.update_list(list, params) do
      Broadcast.lists(family_id, "list:updated", %{list: ListJSON.list(list)})
      json(conn, ListJSON.list(list))
    end
  end

  def delete(conn, %{"id" => id}) do
    family_id = conn.assigns.current_user.family_id

    with %List{} = list <- Lists.get_list(family_id, id),
         {:ok, _} <- Lists.delete_list(list) do
      Broadcast.lists(family_id, "list:deleted", %{id: list.id})
      send_resp(conn, :no_content, "")
    end
  end
end
