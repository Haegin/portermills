defmodule Portermills.Lists.ListItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "list_items" do
    field :name, :string
    field :checked, :boolean, default: false
    field :position, :integer

    belongs_to :list, Portermills.Lists.List
    belongs_to :added_by, Portermills.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :checked, :position])
    |> validate_required([:name, :list_id])
    |> validate_length(:name, max: 255)
  end
end
