defmodule Portermills.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Portermills.Repo,
      {Phoenix.PubSub, name: Portermills.PubSub},
      PortermillsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Portermills.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PortermillsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
