defmodule PortermillsWeb.AuthController do
  use PortermillsWeb, :controller

  alias Portermills.{Accounts, Guardian}

  # Always answers the same way, so the endpoint can't be used to find out
  # which emails belong to family members.
  def request_magic_link(conn, %{"email" => email}) when is_binary(email) do
    Accounts.deliver_magic_link(email, fn token ->
      PortermillsWeb.Endpoint.url() <> "/auth/magic/" <> token
    end)

    json(conn, %{message: "If that email belongs to a family member, a sign-in link is on its way."})
  end

  def request_magic_link(_conn, _params), do: {:error, :bad_request}

  def verify_magic_link(conn, %{"token" => token}) do
    case Accounts.verify_magic_token(token) do
      {:ok, user} ->
        {:ok, jwt, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{token: jwt, user: user_json(user)})

      {:error, _} ->
        conn |> put_status(:unauthorized) |> json(%{error: "Invalid or expired token"})
    end
  end

  def verify_magic_link(_conn, _params), do: {:error, :bad_request}

  def me(conn, _params) do
    json(conn, %{user: user_json(conn.assigns.current_user)})
  end

  def members(conn, _params) do
    members = Accounts.list_family_members(conn.assigns.current_user.family_id)
    json(conn, Enum.map(members, &%{id: &1.id, name: &1.name, role: &1.role}))
  end

  defp user_json(user) do
    %{id: user.id, name: user.name, email: user.email, role: user.role, family_id: user.family_id}
  end
end
