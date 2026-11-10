defmodule Portermills.Repo.Migrations.CreateFamiliesAndUsers do
  use Ecto.Migration

  def change do
    create table(:families, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false
      add :role, :string, null: false, default: "member"
      add :family_id, references(:families, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:family_id])

    create table(:magic_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:magic_tokens, [:token])
    create index(:magic_tokens, [:user_id])
  end
end
