defmodule PortermillsWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :portermills,
    module: Portermills.Guardian,
    error_handler: PortermillsWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
