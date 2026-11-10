defmodule Mix.Tasks.Portermills.AddUser do
  @shortdoc "Adds a family member: mix portermills.add_user NAME EMAIL [--admin] [--family NAME]"
  @moduledoc """
  There is no sign-up; family members are added from the command line.

      mix portermills.add_user "Sam" sam@example.com
      mix portermills.add_user "Alex" alex@example.com --admin --family "Porter-Mills"

  The user joins the family named by `--family`, or the only family if there
  is exactly one. A family that doesn't exist yet is created.
  """
  use Mix.Task

  alias Portermills.{Accounts, Repo}
  alias Portermills.Accounts.Family

  @impl true
  def run(args) do
    {opts, positional} = OptionParser.parse!(args, strict: [admin: :boolean, family: :string])

    [name, email] =
      case positional do
        [_, _] -> positional
        _ -> Mix.raise("usage: mix portermills.add_user NAME EMAIL [--admin] [--family NAME]")
      end

    Mix.Task.run("app.start")

    family = find_or_create_family(opts[:family])
    role = if opts[:admin], do: :admin, else: :member

    case Accounts.create_user(family, %{name: name, email: email, role: role}) do
      {:ok, user} -> Mix.shell().info("Added #{user.name} <#{user.email}> to #{family.name}")
      {:error, changeset} -> Mix.raise("could not add user: #{inspect(changeset.errors)}")
    end
  end

  defp find_or_create_family(nil) do
    case Repo.all(Family) do
      [family] -> family
      [] -> Mix.raise("no family exists yet; pass --family NAME to create one")
      _ -> Mix.raise("more than one family exists; pass --family NAME")
    end
  end

  defp find_or_create_family(name) do
    case Repo.get_by(Family, name: name) do
      nil ->
        {:ok, family} = Accounts.create_family(%{name: name})
        family

      family ->
        family
    end
  end
end
