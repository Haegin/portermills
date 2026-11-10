defmodule Portermills.Lists.Template do
  @moduledoc """
  A reusable packing list ("Beach holiday", "Camping"). Templates are stored
  apart from live lists; creating a list from one copies its items.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "list_templates" do
    field :name, :string

    belongs_to :family, Portermills.Accounts.Family

    has_many :items, Portermills.Lists.TemplateItem,
      preload_order: [asc: :position],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name])
    |> validate_required([:name, :family_id])
    |> validate_length(:name, max: 255)
  end
end
