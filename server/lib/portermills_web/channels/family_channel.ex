defmodule PortermillsWeb.FamilyChannel do
  use Phoenix.Channel

  # Handles topics: "family:<id>:calendar", "family:<id>:lists", "family:<id>:wishlists"
  # Each subtopic is joined independently so clients only subscribe to what they need.

  def join("family:" <> rest, _params, socket) do
    [family_id | _] = String.split(rest, ":")
    user = socket.assigns.current_user

    if user.family_id == family_id do
      {:ok, assign(socket, :family_id, family_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("list:toggle_item", %{"item_id" => item_id, "checked" => checked}, socket) do
    item = Portermills.Lists.get_item!(item_id)
    {:ok, updated} = Portermills.Lists.toggle_item(item, checked)
    broadcast!(socket, "list:item_updated", %{item: updated})
    {:noreply, socket}
  end

  def handle_in("list:add_item", %{"list_id" => list_id, "name" => name}, socket) do
    {:ok, item} = Portermills.Lists.add_item(%{
      list_id: list_id,
      name: name,
      added_by_id: socket.assigns.current_user.id
    })
    broadcast!(socket, "list:item_added", %{item: item})
    {:noreply, socket}
  end

  def handle_in("calendar:create_event", params, socket) do
    attrs = Map.merge(params, %{
      "family_id" => socket.assigns.family_id,
      "created_by_id" => socket.assigns.current_user.id
    })
    {:ok, event} = Portermills.Calendar.create_event(attrs)
    broadcast!(socket, "calendar:event_created", %{event: event})
    {:noreply, socket}
  end
end
