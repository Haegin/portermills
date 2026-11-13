defmodule PortermillsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :portermills

  @session_options [
    store: :cookie,
    key: "_portermills_key",
    signing_salt: "pm_session",
    same_site: "Lax"
  ]

  socket "/socket", PortermillsWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug CORSPlug,
    origin: ["http://localhost:*", "https://portermills.app"],
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"]

  @parsers [
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  ]

  # Inbound email webhooks carry whole emails (attachments included, twice: decoded
  # and in RawEmail), so they get a larger limit than the default 8 MB.
  @default_parsers Plug.Parsers.init(@parsers)
  @inbound_email_parsers Plug.Parsers.init(@parsers ++ [length: 60_000_000])

  plug :parse_body

  plug Plug.MethodOverride
  plug Plug.Head
  plug PortermillsWeb.Router

  defp parse_body(%Plug.Conn{path_info: ["api", "inbound" | _]} = conn, _opts),
    do: Plug.Parsers.call(conn, @inbound_email_parsers)

  defp parse_body(conn, _opts), do: Plug.Parsers.call(conn, @default_parsers)
end
