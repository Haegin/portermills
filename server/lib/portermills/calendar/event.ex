defmodule Portermills.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :description,
             :starts_at,
             :ends_at,
             :all_day,
             :recurrence_rule,
             :family_id,
             :created_by_id
           ]}

  schema "calendar_events" do
    field :title, :string
    field :description, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :all_day, :boolean, default: false
    field :recurrence_rule, :string

    # Set for events imported from emailed invites (see Portermills.EmailInvites).
    field :ical_uid, :string
    field :ical_sequence, :integer, default: 0

    belongs_to :family, Portermills.Accounts.Family
    belongs_to :created_by, Portermills.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :starts_at, :ends_at, :all_day, :recurrence_rule, :family_id, :created_by_id])
    |> validate_required([:title, :starts_at, :ends_at, :family_id, :created_by_id])
  end

  @doc "Changeset for events created from an emailed invite; also tracks the invite's UID."
  def import_changeset(event, attrs) do
    event
    |> changeset(attrs)
    |> cast(attrs, [:ical_uid, :ical_sequence])
    |> unique_constraint([:family_id, :ical_uid])
  end
end
