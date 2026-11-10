defmodule Portermills.Wishlists.Wishlist do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wl_wishlists" do
    field :is_visible_to_family, :boolean, default: true

    belongs_to :user, Portermills.Accounts.User
    has_many :items, Portermills.Wishlists.WishlistItem

    timestamps(type: :utc_datetime)
  end

  def changeset(wishlist, attrs) do
    wishlist
    |> cast(attrs, [:is_visible_to_family, :user_id])
    |> validate_required([:user_id])
  end
end
