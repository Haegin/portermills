defmodule Portermills.Wishlists.Claim do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Claims are intentionally hidden from the wishlist owner.
  # Never include them in responses destined for the item's own user.
  schema "wl_claims" do
    belongs_to :item, Portermills.Wishlists.WishlistItem
    belongs_to :claimed_by, Portermills.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(claim, attrs \\ %{}) do
    claim
    |> cast(attrs, [])
    |> validate_required([:item_id, :claimed_by_id])
    |> unique_constraint(:item_id)
  end
end
