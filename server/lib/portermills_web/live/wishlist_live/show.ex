defmodule PortermillsWeb.WishlistLive.Show do
  @moduledoc """
  Public, read-only page for a wishlist its owner chose to share, for people
  outside the family. It is addressed by an unguessable share token rather
  than by a login, shows no claim data, and updates live as items change.
  """
  use PortermillsWeb, :live_view

  alias Portermills.Wishlists

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Wishlists.get_wishlist_by_share_token(token) do
      nil ->
        raise Ecto.NoResultsError, queryable: Wishlists.Wishlist

      wishlist ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(
            Portermills.PubSub,
            PortermillsWeb.Broadcast.topic(wishlist.user.family_id, "wishlists")
          )
        end

        {:ok,
         socket
         |> assign(:token, token)
         |> assign(:wishlist, wishlist)
         |> assign(:items, Wishlists.list_public_items(wishlist))}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "wishlist:updated", payload: payload}, socket) do
    if payload.wishlist_id == socket.assigns.wishlist.id do
      # Re-read by token: if sharing was turned off, stop showing anything.
      case Wishlists.get_wishlist_by_share_token(socket.assigns.token) do
        nil -> {:noreply, assign(socket, :items, [])}
        wishlist -> {:noreply, assign(socket, :items, Wishlists.list_public_items(wishlist))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <h1>{@wishlist.user.name}'s wishlist</h1>
    <p :if={@items == []} class="empty">Nothing on the list yet.</p>
    <ul>
      <li :for={item <- @items} id={"item-#{item.id}"}>
        <div class="name">{item.name}</div>
        <div :if={item.price} class="meta">£{Decimal.to_string(item.price, :normal)}</div>
        <div :if={item.notes} class="meta">{item.notes}</div>
        <a :if={safe_url?(item.url)} href={item.url} rel="noopener noreferrer" target="_blank">
          View item
        </a>
      </li>
    </ul>
    """
  end

  defp safe_url?(url) when is_binary(url), do: String.starts_with?(url, ["https://", "http://"])
  defp safe_url?(_), do: false
end
