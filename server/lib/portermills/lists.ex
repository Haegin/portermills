defmodule Portermills.Lists do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Lists.{List, ListItem}

  def list_lists(family_id) do
    Repo.all(from l in List, where: l.family_id == ^family_id and not l.archived, order_by: l.name)
  end

  def get_list!(id), do: Repo.get!(List, id)

  def create_list(attrs) do
    %List{}
    |> List.changeset(attrs)
    |> Repo.insert()
  end

  def list_items(list_id) do
    Repo.all(from i in ListItem, where: i.list_id == ^list_id, order_by: i.position)
  end

  def add_item(attrs) do
    position = next_position(attrs[:list_id] || attrs["list_id"])

    %ListItem{}
    |> ListItem.changeset(Map.put(attrs, :position, position))
    |> Repo.insert()
  end

  def toggle_item(%ListItem{} = item, checked) do
    item
    |> ListItem.changeset(%{checked: checked})
    |> Repo.update()
  end

  def delete_item(%ListItem{} = item), do: Repo.delete(item)

  def get_item!(id), do: Repo.get!(ListItem, id)

  defp next_position(list_id) do
    Repo.one(from i in ListItem, where: i.list_id == ^list_id, select: max(i.position)) |> Kernel.||(0) |> Kernel.+(1)
  end
end
