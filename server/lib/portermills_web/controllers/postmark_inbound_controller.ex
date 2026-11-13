defmodule PortermillsWeb.PostmarkInboundController do
  @moduledoc """
  Postmark inbound webhook: receives mail sent to app@portermills.net (forwarded there
  by a Fastmail alias) and imports any calendar invites via `Portermills.EmailInvites`.

  Postmark setup (Servers → your server → Default Inbound Stream → Settings):

    * Webhook URL: `https://USER:PASS@<host>/api/inbound/postmark`, with USER/PASS
      matching `POSTMARK_INBOUND_USERNAME` / `POSTMARK_INBOUND_PASSWORD`.
    * Enable "Include raw email content in JSON payload": the importer verifies DKIM
      signatures, which needs the message exactly as sent.

  Responses: 200 once the email is handled, including when it is rejected (retrying
  wouldn't change that); 422 if `RawEmail` is missing; anything else (a crash, the
  database being down) is a 5xx, which Postmark retries.
  """

  use PortermillsWeb, :controller

  require Logger

  alias Portermills.EmailInvites

  plug :authenticate

  def create(conn, %{"RawEmail" => raw} = params) when is_binary(raw) and raw != "" do
    description = "#{inspect(params["Subject"])} from #{inspect(params["From"])}"

    case EmailInvites.import_email(raw) do
      {:ok, []} ->
        Logger.info("Email invites: no calendar invite in #{description}")
        json(conn, %{status: "no_invite"})

      {:ok, outcomes} ->
        Logger.info(
          "Email invites: #{description}: #{Enum.map_join(outcomes, ", ", &describe/1)}"
        )

        json(conn, %{status: "processed"})

      {:rejected, reason} ->
        Logger.warning("Email invites: rejected #{description}: #{inspect(reason)}")
        json(conn, %{status: "rejected"})
    end
  end

  def create(conn, _params) do
    Logger.error(
      "Email invites: Postmark payload has no RawEmail. Enable \"Include raw email " <>
        "content in JSON payload\" in the inbound stream's settings."
    )

    conn |> put_status(:unprocessable_entity) |> json(%{error: "RawEmail missing"})
  end

  defp describe({:skipped, reason}), do: "skipped (#{inspect(reason)})"
  defp describe({outcome, event}), do: "#{outcome} #{inspect(event.title)}"

  # The endpoint is disabled (404) until credentials are configured.
  defp authenticate(conn, _opts) do
    case Application.get_env(:portermills, __MODULE__, [])[:basic_auth] do
      [username: username, password: password] when username != "" and password != "" ->
        Plug.BasicAuth.basic_auth(conn, username: username, password: password)

      _ ->
        conn |> send_resp(:not_found, "") |> halt()
    end
  end
end
