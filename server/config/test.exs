import Config

config :portermills, Portermills.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  password: System.get_env("PGPASSWORD") || "postgres",
  hostname: System.get_env("PGHOST") || "localhost",
  database: "portermills_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :portermills, PortermillsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_chars_long_for_testing_purposes_only",
  server: false

config :portermills, Portermills.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
