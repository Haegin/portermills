defmodule PortermillsWeb.MagicLinkController do
  @moduledoc """
  The page a magic-link email points at. Mail clients won't linkify a custom
  URL scheme, so the email carries an https link to this page, which hands the
  token to the app via `portermills://auth?token=…`. The token is not consumed
  here; the app exchanges it at `POST /api/auth/verify`.
  """
  use Phoenix.Controller, formats: [:html]

  def show(conn, %{"token" => token}) do
    if token =~ ~r/\A[A-Za-z0-9_-]{20,100}\z/ do
      app_link = "portermills://auth?token=" <> token

      html(conn, """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Sign in to Portermills</title>
          <style>
            body { font-family: system-ui, sans-serif; max-width: 28rem; margin: 4rem auto; padding: 0 1.5rem; text-align: center; color: #1c1b1f; }
            a.button { display: inline-block; margin-top: 1rem; padding: .9rem 1.6rem; border-radius: 999px; background: #2f6f5e; color: #fff; text-decoration: none; font-weight: 600; }
            p { color: #555; }
          </style>
        </head>
        <body>
          <h1>Portermills</h1>
          <p>Open this page on the phone that has the app installed.</p>
          <a class="button" href="#{app_link}">Sign in to the app</a>
        </body>
      </html>
      """)
    else
      conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
