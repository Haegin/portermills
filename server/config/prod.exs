import Config

# Everything environment-specific is read at boot in config/runtime.exs.
config :portermills, Portermills.Mailer, adapter: Swoosh.Adapters.SMTP
config :logger, level: :info
