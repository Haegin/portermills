defmodule Mix.Tasks.Portermills.AddUser do
  @shortdoc "Adds a family member: mix portermills.add_user NAME EMAIL [--admin] [--family NAME]"
  @moduledoc """
  There is no sign-up; family members are added from the command line.

      mix portermills.add_user "Sam" sam@example.com
      mix portermills.add_user "Alex" alex@example.com --admin --family "Porter-Mills"

  The user joins the family named by `--family`, or the only family if there
  is exactly one. A family that doesn't exist yet is created.

  In a release (no Mix), use `bin/add_user` with the same arguments.
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case Portermills.Release.add_user(args) do
      {:ok, message} -> Mix.shell().info(message)
      {:error, message} -> Mix.raise(message)
    end
  end
end
