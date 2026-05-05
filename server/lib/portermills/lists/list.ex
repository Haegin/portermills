defmodule Portermills.Lists.List do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lists" do
    field :type, Ecto.Enum, values: [:shopping, :packing]
    field :name, :string
    field :archived, :boolean, default: false

    belongs_to :family, Portermills.Accounts.Family
    has_many :items, Portermills.Lists.ListItem

    timestamps(type: :utc_datetime)
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:type, :name, :archived, :family_id])
    |> validate_required([:type, :name, :family_id])
  end
end
