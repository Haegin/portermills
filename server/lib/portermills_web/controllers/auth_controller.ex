defmodule PortermillsWeb.AuthController do
  use PortermillsWeb, :controller

  alias Portermills.{Accounts, Guardian}

  def request_magic_link(conn, %{"email" => email}) do
    case Accounts.create_magic_link(email) do
      {:ok, _token} ->
        # In production, send via email (Swoosh). For now, log it.
        json(conn, %{message: "Magic link sent if email is registered"})

      {:error, :not_found} ->
        json(conn, %{message: "Magic link sent if email is registered"})
    end
  end

  def verify_magic_link(conn, %{"token" => token}) do
    case Accounts.verify_magic_token(token) do
      {:ok, user} ->
        {:ok, jwt, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{token: jwt, user: %{id: user.id, name: user.name, email: user.email}})

      {:error, _} ->
        conn |> put_status(:unauthorized) |> json(%{error: "Invalid or expired token"})
    end
  end

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    json(conn, %{user: %{id: user.id, name: user.name, email: user.email, role: user.role}})
  end
end
