import Config

if System.get_env("PHX_SERVER") do
  config :portermills, PortermillsWeb.Endpoint, server: true
end

if config_env() == :prod do
  fetch! = fn name ->
    System.get_env(name) || raise "environment variable #{name} is missing"
  end

  host = fetch!.("PHX_HOST")

  config :portermills, Portermills.Repo,
    url: fetch!.("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # TLS is terminated in front of the app (e.g. a Cloudflare tunnel), so the
  # public URL is https on 443 while the app itself listens on plain HTTP.
  config :portermills, PortermillsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "2310")],
    secret_key_base: fetch!.("SECRET_KEY_BASE")

  config :portermills, Portermills.Guardian, secret_key: fetch!.("GUARDIAN_SECRET")

  config :portermills, mail_from: {"Porter-Mills", fetch!.("MAIL_FROM")}

  config :portermills, Portermills.Mailer,
    relay: System.get_env("SMTP_HOST") || "smtp.fastmail.com",
    port: String.to_integer(System.get_env("SMTP_PORT") || "465"),
    username: fetch!.("SMTP_USERNAME"),
    password: fetch!.("SMTP_PASSWORD"),
    ssl: true,
    tls: :never,
    auth: :always,
    sockopts: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(System.get_env("SMTP_HOST") || "smtp.fastmail.com"),
      # Fastmail's certificate names *.fastmail.com; OTP only matches wildcards
      # when given the HTTPS-style match function.
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)],
      depth: 3
    ]
end
