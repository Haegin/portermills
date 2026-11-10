defmodule PortermillsWeb.FamilyChannel do
  @moduledoc """
  Read-only notifications for a family. Topics: `family:<id>:calendar`,
  `family:<id>:lists`, `family:<id>:wishlists`, each joined independently.

  All writes go through the REST API, which broadcasts here (see
  `PortermillsWeb.Broadcast`).
  """
  use PortermillsWeb, :channel

  @features ~w(calendar lists wishlists)

  intercept ["wishlist:claims_changed"]

  @impl true
  def join("family:" <> rest, _params, socket) do
    user = socket.assigns.current_user

    case String.split(rest, ":") do
      [family_id, feature] when feature in @features and family_id == user.family_id ->
        {:ok, socket}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  # Nothing is written through the channel.
  @impl true
  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "unsupported"}}, socket}
  end

  # The owner of a wishlist must not find out that one of their items was
  # claimed or released, so they never receive this event.
  @impl true
  def handle_out("wishlist:claims_changed", %{owner_id: owner_id} = payload, socket) do
    if socket.assigns.current_user.id != owner_id do
      push(socket, "wishlist:claims_changed", Map.delete(payload, :owner_id))
    end

    {:noreply, socket}
  end
end
