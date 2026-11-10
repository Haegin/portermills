defmodule PortermillsWeb.ListJSON do
  alias Portermills.Lists.{List, ListItem, Template}

  def list(%List{} = l) do
    %{
      id: l.id,
      type: l.type,
      name: l.name,
      archived: l.archived,
      family_id: l.family_id,
      item_count: l.item_count,
      checked_count: l.checked_count
    }
  end

  def item(%ListItem{} = i) do
    %{
      id: i.id,
      list_id: i.list_id,
      name: i.name,
      checked: i.checked,
      position: i.position,
      added_by_id: i.added_by_id
    }
  end

  def template(%Template{} = t) do
    %{
      id: t.id,
      name: t.name,
      family_id: t.family_id,
      items: Enum.map(t.items, &%{id: &1.id, name: &1.name, position: &1.position})
    }
  end
end
