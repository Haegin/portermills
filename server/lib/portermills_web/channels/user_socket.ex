defmodule PortermillsWeb.UserSocket do
  use Phoenix.Socket

  channel "family:*", PortermillsWeb.FamilyChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Portermills.Guardian.resource_from_token(token) do
      {:ok, user, _claims} -> {:ok, assign(socket, :current_user, user)}
      _ -> :error
    end
  end

  def connect(_, _socket, _), do: :error

  @impl true
  def id(%{assigns: %{current_user: user}}), do: "user:#{user.id}"
end
