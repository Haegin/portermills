defmodule Portermills.Repo do
  use Ecto.Repo,
    otp_app: :portermills,
    adapter: Ecto.Adapters.Postgres
end
