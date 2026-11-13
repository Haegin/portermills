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
    ] ++ email_invite_children()

    opts = [strategy: :one_for_one, name: Portermills.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Polls Fastmail for emailed invites; only runs when FASTMAIL_API_TOKEN is set.
  defp email_invite_children do
    config = Application.get_env(:portermills, Portermills.EmailInvites.Poller, [])
    if config[:enabled], do: [{Portermills.EmailInvites.Poller, config}], else: []
  end

  @impl true
  def config_change(changed, _new, removed) do
    PortermillsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
