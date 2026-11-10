defmodule PortermillsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :portermills

  # Only the public wishlist page uses the session (for LiveView's CSRF check).
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

  # The LiveView client scripts, served straight from the deps (no asset build).
  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/assets/phoenix_live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :portermills
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PortermillsWeb.Router
end
