import Config

# Email invites: poll the Fastmail mailbox that receives app@portermills.net and
# add forwarded calendar invites to the sender's family calendar.
if config_env() != :test do
  if token = System.get_env("FASTMAIL_API_TOKEN") do
    config :portermills, Portermills.EmailInvites.Poller,
      enabled: true,
      token: token,
      address: System.get_env("INVITES_EMAIL_ADDRESS", "app@portermills.net"),
      interval_ms: String.to_integer(System.get_env("INVITES_POLL_SECONDS", "60")) * 1000
  end

  if time_zone = System.get_env("DEFAULT_TIME_ZONE") do
    config :portermills, Portermills.EmailInvites, default_time_zone: time_zone
  end
end
