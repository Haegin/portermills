import Config

config :portermills, Portermills.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "portermills_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :portermills, PortermillsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_chars_long_for_testing_purposes_only",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

# Email invite tests: fixed webhook credentials, and DKIM keys from a fixture file
# instead of DNS.
config :portermills, PortermillsWeb.PostmarkInboundController,
  basic_auth: [username: "postmark", password: "test-webhook-secret"]

config :portermills, Portermills.EmailInvites.DKIM,
  txt_lookup: {Portermills.EmailInviteFixtures, :dns_txt}
