defmodule Portermills.Wishlists do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Wishlists.{Wishlist, WishlistItem, Claim}

  def list_family_wishlists(family_id) do
    Repo.all(
      from w in Wishlist,
        join: u in assoc(w, :user),
        where: u.family_id == ^family_id and w.is_visible_to_family,
        preload: :user
    )
  end

  def get_or_create_wishlist(user_id) do
    case Repo.get_by(Wishlist, user_id: user_id) do
      nil ->
        %Wishlist{}
        |> Wishlist.changeset(%{user_id: user_id})
        |> Repo.insert!()

      wishlist ->
        wishlist
    end
  end

  def list_items(wishlist_id, viewing_user_id) do
    wishlist = Repo.get!(Wishlist, wishlist_id)
    is_owner = wishlist.user_id == viewing_user_id

    items =
      Repo.all(
        from i in WishlistItem,
          where: i.wishlist_id == ^wishlist_id,
          preload: :claim
      )

    if is_owner do
      # Owner never sees claim data
      Enum.map(items, &Map.put(&1, :claim, nil))
    else
      items
    end
  end

  def add_item(attrs) do
    %WishlistItem{}
    |> WishlistItem.changeset(attrs)
    |> Repo.insert()
  end

  def claim_item(item_id, claimed_by_id) do
    %Claim{}
    |> Claim.changeset(%{item_id: item_id, claimed_by_id: claimed_by_id})
    |> Repo.insert()
  end

  def unclaim_item(item_id, claimed_by_id) do
    Repo.delete_all(
      from c in Claim,
        where: c.item_id == ^item_id and c.claimed_by_id == ^claimed_by_id
    )
  end
end
