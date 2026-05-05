defmodule Portermills.Repo.Migrations.CreateWishlists do
  use Ecto.Migration

  def change do
    create table(:wl_wishlists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :is_visible_to_family, :boolean, default: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:wl_wishlists, [:user_id])

    create table(:wl_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :url, :string
      add :notes, :text
      add :price, :decimal, precision: 10, scale: 2
      add :priority, :string, default: "medium", null: false
      add :wishlist_id, references(:wl_wishlists, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:wl_items, [:wishlist_id])

    create table(:wl_claims, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :item_id, references(:wl_items, type: :binary_id, on_delete: :delete_all), null: false
      add :claimed_by_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:wl_claims, [:item_id])
  end
end
