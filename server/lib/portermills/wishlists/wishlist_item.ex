defmodule Portermills.Wishlists.WishlistItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wl_items" do
    field :name, :string
    field :url, :string
    field :notes, :string
    field :price, :decimal
    field :priority, Ecto.Enum, values: [:low, :medium, :high], default: :medium

    belongs_to :wishlist, Portermills.Wishlists.Wishlist
    has_one :claim, Portermills.Wishlists.Claim

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :url, :notes, :price, :priority, :wishlist_id])
    |> validate_required([:name, :wishlist_id])
  end
end
