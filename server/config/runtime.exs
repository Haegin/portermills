import Config

if config_env() != :test do
  # Email invites: Postmark POSTs inbound mail to /api/inbound/postmark using these
  # basic-auth credentials (put them in the webhook URL). Unset = endpoint disabled.
  username = System.get_env("POSTMARK_INBOUND_USERNAME")
  password = System.get_env("POSTMARK_INBOUND_PASSWORD")

  if username && password do
    config :portermills, PortermillsWeb.PostmarkInboundController,
      basic_auth: [username: username, password: password]
  end

  if time_zone = System.get_env("DEFAULT_TIME_ZONE") do
    config :portermills, Portermills.EmailInvites, default_time_zone: time_zone
  end
end
