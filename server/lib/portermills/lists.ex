defmodule Portermills.Lists do
  @moduledoc """
  Shopping and packing lists, their items, and packing-list templates.
  Everything is scoped to a family. Shares nothing with `Portermills.Wishlists`.
  """
  import Ecto.Query
  alias Ecto.Multi
  alias Portermills.Repo
  alias Portermills.Lists.{List, ListItem, Template, TemplateItem}

  # -- Lists ---------------------------------------------------------------

  def list_lists(family_id) do
    Repo.all(
      from l in lists_with_counts(),
        where: l.family_id == ^family_id and not l.archived,
        order_by: [desc: l.type, asc: l.name]
    )
  end

  def get_list(family_id, id) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      Repo.one(from l in lists_with_counts(), where: l.id == ^id and l.family_id == ^family_id)
    else
      :error -> nil
    end
  end

  defp lists_with_counts do
    from l in List,
      left_join: i in assoc(l, :items),
      group_by: l.id,
      select_merge: %{
        item_count: count(i.id),
        checked_count: fragment("count(*) filter (where ?)", i.checked)
      }
  end

  def create_list(family_id, attrs) do
    %List{family_id: family_id}
    |> List.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Creates a packing list holding a copy of the template's items."
  def create_list_from_template(%Template{} = template, user_id, attrs \\ %{}) do
    template = Repo.preload(template, :items)
    name = attrs["name"] || attrs[:name] || template.name
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.insert(
      :list,
      List.create_changeset(%List{family_id: template.family_id}, %{type: :packing, name: name})
    )
    |> Multi.insert_all(:items, ListItem, fn %{list: list} ->
      for item <- template.items do
        %{
          id: Ecto.UUID.generate(),
          list_id: list.id,
          name: item.name,
          position: item.position,
          checked: false,
          added_by_id: user_id,
          inserted_at: now,
          updated_at: now
        }
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{list: list}} -> {:ok, %{list | item_count: length(template.items)}}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  def update_list(%List{} = list, attrs) do
    list |> List.update_changeset(attrs) |> Repo.update()
  end

  def delete_list(%List{} = list), do: Repo.delete(list)

  # -- Items ---------------------------------------------------------------

  def list_items(%List{id: list_id}) do
    Repo.all(
      from i in ListItem, where: i.list_id == ^list_id, order_by: [i.position, i.inserted_at]
    )
  end

  def get_item(%List{id: list_id}, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get_by(ListItem, id: id, list_id: list_id)
      :error -> nil
    end
  end

  def add_item(%List{id: list_id}, user_id, attrs) do
    %ListItem{list_id: list_id, added_by_id: user_id, position: next_position(list_id)}
    |> ListItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_item(%ListItem{} = item, attrs) do
    item |> ListItem.changeset(attrs) |> Repo.update()
  end

  def delete_item(%ListItem{} = item), do: Repo.delete(item)

  defp next_position(list_id) do
    max = Repo.one(from i in ListItem, where: i.list_id == ^list_id, select: max(i.position))
    (max || 0) + 1
  end

  # -- Packing-list templates ----------------------------------------------

  def list_templates(family_id) do
    Repo.all(
      from t in Template, where: t.family_id == ^family_id, order_by: t.name, preload: :items
    )
  end

  def get_template(family_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Repo.one(
          from t in Template, where: t.id == ^id and t.family_id == ^family_id, preload: :items
        )

      :error ->
        nil
    end
  end

  @doc """
  Creates a template. `attrs` has a `name` and optionally `items`, a list of
  item names in order.
  """
  def create_template(family_id, attrs) do
    %Template{family_id: family_id, items: []}
    |> template_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Saves the current items of a list as a new template."
  def create_template_from_list(%List{} = list, attrs \\ %{}) do
    names = list |> list_items() |> Enum.map(& &1.name)
    name = attrs["name"] || attrs[:name] || list.name
    create_template(list.family_id, %{"name" => name, "items" => names})
  end

  def update_template(%Template{} = template, attrs) do
    template
    |> Repo.preload(:items)
    |> template_changeset(attrs)
    |> Repo.update()
  end

  def delete_template(%Template{} = template), do: Repo.delete(template)

  defp template_changeset(template, attrs) do
    changeset = Template.changeset(template, attrs)

    case attrs["items"] || attrs[:items] do
      names when is_list(names) ->
        items =
          names
          |> Enum.with_index(1)
          |> Enum.map(fn {name, position} ->
            TemplateItem.changeset(%TemplateItem{}, %{name: name, position: position})
          end)

        Ecto.Changeset.put_assoc(changeset, :items, items)

      _ ->
        changeset
    end
  end
end
