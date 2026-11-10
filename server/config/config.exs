import Config

config :portermills,
  ecto_repos: [Portermills.Repo],
  generators: [timestamp_type: :utc_datetime],
  mail_from: {"Porter-Mills", "noreply@localhost"},
  log_magic_links: false

config :portermills, PortermillsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PortermillsWeb.ErrorJSON, html: PortermillsWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Portermills.PubSub,
  live_view: [signing_salt: "portermills_lv"]

config :portermills, Portermills.Mailer, adapter: Swoosh.Adapters.Local
config :swoosh, :api_client, false

config :portermills, Portermills.Guardian,
  issuer: "portermills",
  ttl: {52, :weeks},
  secret_key: "dev_only_guardian_secret_overridden_in_runtime_exs_for_prod"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
