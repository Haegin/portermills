defmodule Portermills.Repo.Migrations.AddShareTokenToWishlists do
  use Ecto.Migration

  def change do
    alter table(:wl_wishlists) do
      add :share_token, :string
    end

    create unique_index(:wl_wishlists, [:share_token])
  end
end
