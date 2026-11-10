defmodule Portermills.Release do
  @moduledoc """
  Tasks for a production release, where Mix isn't available. Called by the
  `bin/migrate` and `bin/add_user` scripts in `rel/overlays/bin`.
  """
  @app :portermills

  def migrate do
    load_app()

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Entry point for `bin/add_user NAME EMAIL [--admin] [--family NAME]`."
  def add_user_cli(args) do
    load_app()

    # Only the repo is started, so this works alongside the running server.
    {:ok, result, _} = Ecto.Migrator.with_repo(Portermills.Repo, fn _ -> add_user(args) end)

    case result do
      {:ok, message} ->
        IO.puts(message)

      {:error, message} ->
        IO.puts(:stderr, message)
        System.halt(1)
    end
  end

  @usage "usage: add_user NAME EMAIL [--admin] [--family NAME]"

  def add_user(args) do
    case OptionParser.parse(args, strict: [admin: :boolean, family: :string]) do
      {opts, [name, email], []} ->
        role = if opts[:admin], do: :admin, else: :member

        case Portermills.Accounts.add_family_member(name, email, role, opts[:family]) do
          {:ok, user, family} ->
            {:ok, "Added #{user.name} <#{user.email}> to #{family.name}"}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, "could not add user: #{inspect(changeset.errors)}"}

          {:error, message} ->
            {:error, message}
        end

      _ ->
        {:error, @usage}
    end
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
