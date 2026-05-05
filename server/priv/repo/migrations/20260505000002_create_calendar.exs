defmodule Portermills.Repo.Migrations.CreateCalendar do
  use Ecto.Migration

  def change do
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false
      add :all_day, :boolean, default: false, null: false
      add :recurrence_rule, :string
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:family_id, :starts_at])
  end
end
