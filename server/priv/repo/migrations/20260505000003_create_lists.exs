defmodule Portermills.Repo.Migrations.CreateLists do
  use Ecto.Migration

  def change do
    create table(:lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :name, :string, null: false
      add :archived, :boolean, default: false, null: false
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:lists, [:family_id])

    create table(:list_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :checked, :boolean, default: false, null: false
      add :position, :integer
      add :list_id, references(:lists, type: :binary_id, on_delete: :delete_all), null: false
      add :added_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:list_items, [:list_id, :position])
  end
end
