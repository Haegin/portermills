defmodule PortermillsWeb.ListItemController do
  use PortermillsWeb, :controller

  alias Portermills.Lists
  alias Portermills.Lists.{List, ListItem}
  alias PortermillsWeb.ListJSON

  def index(conn, %{"list_id" => list_id}) do
    with %List{} = list <- Lists.get_list(conn.assigns.current_user.family_id, list_id) do
      json(conn, list |> Lists.list_items() |> Enum.map(&ListJSON.item/1))
    end
  end

  def create(conn, %{"list_id" => list_id} = params) do
    user = conn.assigns.current_user

    with %List{} = list <- Lists.get_list(user.family_id, list_id),
         {:ok, item} <- Lists.add_item(list, user.id, params) do
      Broadcast.lists(user.family_id, "list:item_added", %{item: ListJSON.item(item)})
      conn |> put_status(:created) |> json(ListJSON.item(item))
    end
  end

  def update(conn, %{"list_id" => list_id, "id" => id} = params) do
    family_id = conn.assigns.current_user.family_id

    with %List{} = list <- Lists.get_list(family_id, list_id),
         %ListItem{} = item <- Lists.get_item(list, id),
         {:ok, item} <- Lists.update_item(item, params) do
      Broadcast.lists(family_id, "list:item_updated", %{item: ListJSON.item(item)})
      json(conn, ListJSON.item(item))
    end
  end

  def delete(conn, %{"list_id" => list_id, "id" => id}) do
    family_id = conn.assigns.current_user.family_id

    with %List{} = list <- Lists.get_list(family_id, list_id),
         %ListItem{} = item <- Lists.get_item(list, id),
         {:ok, _} <- Lists.delete_item(item) do
      Broadcast.lists(family_id, "list:item_deleted", %{id: item.id, list_id: list.id})
      send_resp(conn, :no_content, "")
    end
  end
end
