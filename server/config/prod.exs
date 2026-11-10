import Config

config :portermills, PortermillsWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "portermills.app", port: 443, scheme: "https"],
  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: System.get_env("PORT") || 4000],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

config :portermills, Portermills.Repo,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true

config :logger, level: :info
