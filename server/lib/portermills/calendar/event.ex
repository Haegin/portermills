defmodule Portermills.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "calendar_events" do
    field :title, :string
    field :description, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :all_day, :boolean, default: false
    field :recurrence_rule, :string

    belongs_to :family, Portermills.Accounts.Family
    belongs_to :created_by, Portermills.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :starts_at, :ends_at, :all_day, :recurrence_rule, :family_id, :created_by_id])
    |> validate_required([:title, :starts_at, :ends_at, :family_id, :created_by_id])
  end
end
