defmodule Portermills.Repo.Migrations.CreateListTemplates do
  use Ecto.Migration

  def change do
    create table(:list_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:list_templates, [:family_id])

    create table(:list_template_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :position, :integer
      add :template_id, references(:list_templates, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:list_template_items, [:template_id, :position])
  end
end
