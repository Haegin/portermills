defmodule Portermills.Accounts.Family do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "families" do
    field :name, :string
    has_many :members, Portermills.Accounts.User, foreign_key: :family_id
    timestamps(type: :utc_datetime)
  end

  def changeset(family, attrs) do
    family
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
