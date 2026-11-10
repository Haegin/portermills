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

  # family_id and created_by_id are set by the context, never from request params.
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :starts_at, :ends_at, :all_day, :recurrence_rule])
    |> validate_required([:title, :starts_at, :ends_at, :family_id])
    |> validate_length(:title, max: 255)
    |> validate_ends_after_start()
  end

  defp validate_ends_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) == :lt do
      add_error(changeset, :ends_at, "must not be before the start")
    else
      changeset
    end
  end
end
