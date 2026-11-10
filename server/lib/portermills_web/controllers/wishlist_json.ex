defmodule PortermillsWeb.WishlistJSON do
  @moduledoc """
  JSON for wishlists. Claim fields (`is_claimed`, `claimed_by_me`,
  `claimed_by_name`) are present only when the viewer is not the wishlist's
  owner: the owner's responses don't carry the keys at all.
  """
  alias Portermills.Accounts.User
  alias Portermills.Wishlists
  alias Portermills.Wishlists.{Wishlist, WishlistItem, Claim}

  def wishlist(%Wishlist{} = w, %User{} = viewer) do
    %{
      id: w.id,
      user_id: w.user_id,
      is_visible_to_family: w.is_visible_to_family,
      is_mine: Wishlists.owner?(w, viewer),
      item_count: w.item_count,
      user: %{id: w.user.id, name: w.user.name}
    }
  end

  def item(%WishlistItem{} = i, %Wishlist{} = wishlist, %User{} = viewer) do
    base = %{
      id: i.id,
      wishlist_id: i.wishlist_id,
      name: i.name,
      url: i.url,
      notes: i.notes,
      price: i.price && Decimal.to_string(i.price, :normal),
      priority: i.priority
    }

    if Wishlists.owner?(wishlist, viewer), do: base, else: Map.merge(base, claim_fields(i, viewer))
  end

  defp claim_fields(%WishlistItem{claim: %Claim{} = claim}, viewer) do
    %{
      is_claimed: true,
      claimed_by_me: claim.claimed_by_id == viewer.id,
      claimed_by_name: claim.claimed_by.name
    }
  end

  defp claim_fields(%WishlistItem{claim: nil}, _viewer) do
    %{is_claimed: false, claimed_by_me: false, claimed_by_name: nil}
  end
end
