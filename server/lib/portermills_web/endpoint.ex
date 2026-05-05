defmodule PortermillsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :portermills

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

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug PortermillsWeb.Router
end
