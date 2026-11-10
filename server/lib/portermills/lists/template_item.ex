defmodule Portermills.Lists.TemplateItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "list_template_items" do
    field :name, :string
    field :position, :integer

    belongs_to :template, Portermills.Lists.Template

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :position])
    |> validate_required([:name])
    |> validate_length(:name, max: 255)
  end
end
