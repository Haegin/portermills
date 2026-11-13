defmodule Portermills.Repo.Migrations.AddIcalFieldsToCalendarEvents do
  use Ecto.Migration

  # Events imported from emailed invites remember the invite's UID and SEQUENCE so
  # that updated invites replace the event and cancellations remove it.
  def change do
    alter table(:calendar_events) do
      add(:ical_uid, :text)
      add(:ical_sequence, :integer, null: false, default: 0)
    end

    create(unique_index(:calendar_events, [:family_id, :ical_uid], where: "ical_uid IS NOT NULL"))
  end
end
