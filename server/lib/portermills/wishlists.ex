defmodule Portermills.Wishlists do
  @moduledoc """
  One wishlist per family member. Other members can claim items; the owner
  must never learn which of their items are claimed, so every read that could
  return claims takes the viewing user and strips them for the owner.

  Shares nothing with `Portermills.Lists`.
  """
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Accounts.User
  alias Portermills.Wishlists.{Wishlist, WishlistItem, Claim}

  # -- Wishlists -----------------------------------------------------------

  @doc """
  The wishlists `viewer` may see: their own plus those of family members who
  haven't hidden theirs. Every family member gets a wishlist on first read.
  """
  def list_family_wishlists(%User{} = viewer) do
    ensure_wishlists(viewer.family_id)

    Repo.all(
      from w in with_counts(),
        join: u in assoc(w, :user),
        where: u.family_id == ^viewer.family_id,
        where: w.is_visible_to_family or w.user_id == ^viewer.id,
        group_by: u.id,
        order_by: u.name,
        preload: [user: u]
    )
  end

  def get_wishlist(%User{} = viewer, id) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      Repo.one(
        from w in with_counts(),
          join: u in assoc(w, :user),
          where: w.id == ^id and u.family_id == ^viewer.family_id,
          where: w.is_visible_to_family or w.user_id == ^viewer.id,
          group_by: u.id,
          preload: [user: u]
      )
    else
      :error -> nil
    end
  end

  def get_or_create_wishlist(%User{id: user_id}) do
    Repo.insert!(%Wishlist{user_id: user_id}, on_conflict: :nothing, conflict_target: :user_id)
    Repo.one!(from w in with_counts(), where: w.user_id == ^user_id, preload: :user)
  end

  def update_wishlist(%Wishlist{} = wishlist, attrs) do
    wishlist |> Wishlist.changeset(attrs) |> Repo.update()
  end

  def owner?(%Wishlist{user_id: owner_id}, %User{id: user_id}), do: owner_id == user_id

  defp with_counts do
    from w in Wishlist,
      left_join: i in assoc(w, :items),
      group_by: w.id,
      select_merge: %{item_count: count(i.id)}
  end

  defp ensure_wishlists(family_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    missing =
      Repo.all(
        from u in User,
          left_join: w in Wishlist,
          on: w.user_id == u.id,
          where: u.family_id == ^family_id and is_nil(w.id),
          select: u.id
      )

    rows =
      for user_id <- missing do
        %{id: Ecto.UUID.generate(), user_id: user_id, is_visible_to_family: true, inserted_at: now, updated_at: now}
      end

    Repo.insert_all(Wishlist, rows, on_conflict: :nothing, conflict_target: :user_id)
  end

  # -- Public sharing ------------------------------------------------------

  @doc "Returns the wishlist with a share token, creating one if needed."
  def ensure_share_token(%Wishlist{share_token: nil} = wishlist) do
    token = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
    wishlist |> Ecto.Changeset.change(share_token: token) |> Repo.update!()
  end

  def ensure_share_token(%Wishlist{} = wishlist), do: wishlist

  def revoke_share_token(%Wishlist{} = wishlist) do
    wishlist |> Ecto.Changeset.change(share_token: nil) |> Repo.update!()
  end

  def get_wishlist_by_share_token(token) when is_binary(token) and token != "" do
    Repo.one(from w in Wishlist, where: w.share_token == ^token, preload: :user)
  end

  def get_wishlist_by_share_token(_), do: nil

  @doc "Items for the public page: never any claim data."
  def list_public_items(%Wishlist{id: wishlist_id}) do
    Repo.all(items_query(wishlist_id))
  end

  # -- Items ---------------------------------------------------------------

  @doc """
  Items of a wishlist as `viewer` may see them. For the owner the `claim`
  association is left unloaded, so claim data cannot leak into a response.
  """
  def list_items(%Wishlist{} = wishlist, %User{} = viewer) do
    items = Repo.all(items_query(wishlist.id))

    if owner?(wishlist, viewer), do: items, else: Repo.preload(items, claim: :claimed_by)
  end

  defp items_query(wishlist_id) do
    from i in WishlistItem,
      where: i.wishlist_id == ^wishlist_id,
      order_by: [
        fragment("case ? when 'high' then 0 when 'medium' then 1 else 2 end", i.priority),
        i.inserted_at
      ]
  end

  def get_item(%Wishlist{} = wishlist, id, %User{} = viewer) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %WishlistItem{} = item <- Repo.get_by(WishlistItem, id: id, wishlist_id: wishlist.id) do
      if owner?(wishlist, viewer), do: item, else: Repo.preload(item, claim: :claimed_by)
    else
      _ -> nil
    end
  end

  @doc "Finds an item by id alone, along with its wishlist, if `viewer` may see it."
  def get_item_with_wishlist(%User{} = viewer, item_id) do
    with {:ok, item_id} <- Ecto.UUID.cast(item_id),
         %WishlistItem{} = item <- Repo.get(WishlistItem, item_id),
         %Wishlist{} = wishlist <- get_wishlist(viewer, item.wishlist_id) do
      {wishlist, item}
    else
      _ -> nil
    end
  end

  def add_item(%Wishlist{id: wishlist_id}, attrs) do
    %WishlistItem{wishlist_id: wishlist_id}
    |> WishlistItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_item(%WishlistItem{} = item, attrs) do
    item |> WishlistItem.changeset(attrs) |> Repo.update()
  end

  def delete_item(%WishlistItem{} = item), do: Repo.delete(item)

  # -- Claims --------------------------------------------------------------

  @doc "Claims an item for `user`. Owners can't claim from their own wishlist."
  def claim_item(%Wishlist{} = wishlist, %WishlistItem{} = item, %User{} = user) do
    if owner?(wishlist, user) do
      {:error, :forbidden}
    else
      %Claim{item_id: item.id, claimed_by_id: user.id}
      |> Claim.changeset()
      |> Repo.insert()
      |> case do
        {:ok, _claim} -> {:ok, reload_with_claim(item)}
        {:error, _changeset} -> {:error, :already_claimed}
      end
    end
  end

  @doc "Removes `user`'s own claim. Someone else's claim is left alone."
  def unclaim_item(%Wishlist{} = wishlist, %WishlistItem{} = item, %User{} = user) do
    if owner?(wishlist, user) do
      {:error, :forbidden}
    else
      Repo.delete_all(from c in Claim, where: c.item_id == ^item.id and c.claimed_by_id == ^user.id)
      {:ok, reload_with_claim(item)}
    end
  end

  defp reload_with_claim(item) do
    Repo.preload(item, [claim: :claimed_by], force: true)
  end
end
