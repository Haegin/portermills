defmodule Portermills.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Portermills.Repo,
      {DNSCluster, query: Application.get_env(:portermills, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Portermills.PubSub},
      {Finch, name: Portermills.Finch},
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
