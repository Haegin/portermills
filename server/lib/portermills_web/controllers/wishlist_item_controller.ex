defmodule PortermillsWeb.WishlistItemController do
  use PortermillsWeb, :controller

  alias Portermills.Wishlists
  alias Portermills.Wishlists.{Wishlist, WishlistItem}
  alias PortermillsWeb.WishlistJSON

  def index(conn, %{"wishlist_id" => wishlist_id}) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, wishlist_id) do
      items = Wishlists.list_items(wishlist, user)
      json(conn, Enum.map(items, &WishlistJSON.item(&1, wishlist, user)))
    end
  end

  def show(conn, %{"wishlist_id" => wishlist_id, "id" => id}) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, wishlist_id),
         %WishlistItem{} = item <- Wishlists.get_item(wishlist, id, user) do
      json(conn, WishlistJSON.item(item, wishlist, user))
    end
  end

  # Only the owner adds to, edits or removes from their wishlist.

  def create(conn, %{"wishlist_id" => wishlist_id} = params) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, wishlist_id),
         :ok <- ensure_owner(wishlist, user),
         {:ok, item} <- Wishlists.add_item(wishlist, params) do
      items_changed(user, wishlist)
      conn |> put_status(:created) |> json(WishlistJSON.item(item, wishlist, user))
    end
  end

  def update(conn, %{"wishlist_id" => wishlist_id, "id" => id} = params) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, wishlist_id),
         :ok <- ensure_owner(wishlist, user),
         %WishlistItem{} = item <- Wishlists.get_item(wishlist, id, user),
         {:ok, item} <- Wishlists.update_item(item, params) do
      items_changed(user, wishlist)
      json(conn, WishlistJSON.item(item, wishlist, user))
    end
  end

  def delete(conn, %{"wishlist_id" => wishlist_id, "id" => id}) do
    user = conn.assigns.current_user

    with %Wishlist{} = wishlist <- Wishlists.get_wishlist(user, wishlist_id),
         :ok <- ensure_owner(wishlist, user),
         %WishlistItem{} = item <- Wishlists.get_item(wishlist, id, user),
         {:ok, _} <- Wishlists.delete_item(item) do
      items_changed(user, wishlist)
      send_resp(conn, :no_content, "")
    end
  end

  def claim(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {wishlist, item} <- Wishlists.get_item_with_wishlist(user, id),
         {:ok, item} <- Wishlists.claim_item(wishlist, item, user) do
      claims_changed(user, wishlist)
      json(conn, WishlistJSON.item(item, wishlist, user))
    end
  end

  def unclaim(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {wishlist, item} <- Wishlists.get_item_with_wishlist(user, id),
         {:ok, item} <- Wishlists.unclaim_item(wishlist, item, user) do
      claims_changed(user, wishlist)
      json(conn, WishlistJSON.item(item, wishlist, user))
    end
  end

  defp ensure_owner(wishlist, user) do
    if Wishlists.owner?(wishlist, user), do: :ok, else: {:error, :forbidden}
  end

  # Carries only ids; clients refetch, and the refetch applies the claim rules.
  defp items_changed(user, wishlist) do
    Broadcast.wishlists(user.family_id, "wishlist:updated", %{wishlist_id: wishlist.id})
  end

  # FamilyChannel drops this event for the wishlist's owner.
  defp claims_changed(user, wishlist) do
    Broadcast.wishlists(user.family_id, "wishlist:claims_changed", %{
      wishlist_id: wishlist.id,
      owner_id: wishlist.user_id
    })
  end
end
