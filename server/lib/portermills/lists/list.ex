defmodule Portermills.Lists.List do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lists" do
    field :type, Ecto.Enum, values: [:shopping, :packing]
    field :name, :string
    field :archived, :boolean, default: false

    field :item_count, :integer, virtual: true, default: 0
    field :checked_count, :integer, virtual: true, default: 0

    belongs_to :family, Portermills.Accounts.Family
    has_many :items, Portermills.Lists.ListItem

    timestamps(type: :utc_datetime)
  end

  def create_changeset(list, attrs) do
    list
    |> cast(attrs, [:type, :name])
    |> validate_required([:type, :name, :family_id])
    |> validate_length(:name, max: 255)
  end

  def update_changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :archived])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
  end
end
