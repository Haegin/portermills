import Config

# Homebrew Postgres has a superuser named after the macOS user and trusts local
# connections, so default to that. Override with PGUSER / PGPASSWORD / PGHOST.
config :portermills, Portermills.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("PGHOST") || "localhost",
  database: "portermills_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Bound to all interfaces so the Android emulator (10.0.2.2) and phones on the
# LAN can reach the dev server.
config :portermills, PortermillsWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "2310")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_chars_long_CHANGE_IN_PRODUCTION_PLEASE",
  watchers: []

# Magic links are written to the log and to the local mailbox at /dev/mailbox.
config :portermills, log_magic_links: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
