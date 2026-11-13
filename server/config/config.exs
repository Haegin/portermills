import Config

config :portermills,
  ecto_repos: [Portermills.Repo],
  generators: [timestamp_type: :utc_datetime]

config :portermills, PortermillsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PortermillsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Portermills.PubSub,
  live_view: [signing_salt: "portermills_lv"]

config :portermills, Portermills.Mailer, adapter: Swoosh.Adapters.Local

# The local mail adapter needs no HTTP client (Swoosh otherwise insists on hackney).
config :swoosh, :api_client, false

config :portermills, Portermills.Guardian,
  issuer: "portermills",
  secret_key: System.get_env("GUARDIAN_SECRET") || "dev_secret_change_in_prod"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Needed to convert invite times given in a named zone (TZID=Europe/London) to UTC.
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Email invites (see Portermills.EmailInvites). The poller itself is configured
# from environment variables in config/runtime.exs.
config :portermills, Portermills.EmailInvites,
  # Used for "floating" invite times that carry no timezone at all.
  default_time_zone: "Etc/UTC",
  # Only trust Authentication-Results headers stamped by Fastmail's MX servers.
  trusted_authserv_suffix: "messagingengine.com"

config :portermills, Portermills.EmailInvites.Fastmail,
  session_url: "https://api.fastmail.com/jmap/session"

import_config "#{config_env()}.exs"
