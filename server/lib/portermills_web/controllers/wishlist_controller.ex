defmodule PortermillsWeb.WishlistController do
  use PortermillsWeb, :controller

  alias Portermills.Wishlists
  alias Portermills.Wishlists.Wishlist
  alias PortermillsWeb.WishlistJSON

  def index(conn, _params) do
    user = conn.assigns.current_user
    wishlists = Wishlists.list_family_wishlists(user)
    json(conn, Enum.map(wishlists, &WishlistJSON.wishlist(&1, user)))
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, id) do
      items = Wishlists.list_items(wishlist, user)

      json(
        conn,
        wishlist
        |> WishlistJSON.wishlist(user)
        |> Map.put(:items, Enum.map(items, &WishlistJSON.item(&1, wishlist, user)))
      )
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- owned(user, id),
         {:ok, updated} <- Wishlists.update_wishlist(wishlist, params) do
      Broadcast.wishlists(user.family_id, "wishlist:updated", %{wishlist_id: wishlist.id})
      json(conn, WishlistJSON.wishlist(%{updated | item_count: wishlist.item_count}, user))
    end
  end

  # Turns on the public read-only web page for this wishlist and returns its URL.
  def share(conn, %{"id" => id}) do
    with %Wishlist{} = wishlist <- owned(conn.assigns.current_user, id) do
      wishlist = Wishlists.ensure_share_token(wishlist)
      json(conn, %{url: PortermillsWeb.Endpoint.url() <> "/wishlists/" <> wishlist.share_token})
    end
  end

  def unshare(conn, %{"id" => id}) do
    with %Wishlist{} = wishlist <- owned(conn.assigns.current_user, id) do
      Wishlists.revoke_share_token(wishlist)
      send_resp(conn, :no_content, "")
    end
  end

  defp owned(user, id) do
    case Wishlists.get_wishlist(user, id) do
      %Wishlist{} = wishlist ->
        if Wishlists.owner?(wishlist, user), do: wishlist, else: {:error, :forbidden}

      nil ->
        nil
    end
  end
end
