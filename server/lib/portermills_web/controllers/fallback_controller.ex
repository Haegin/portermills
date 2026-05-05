defmodule PortermillsWeb.FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{error: "not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
  end

  def call(conn, {:error, %Ecto.Changeset{} = cs}) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
  end

  defp format_errors(%Ecto.Changeset{errors: errors}) do
    Enum.into(errors, %{}, fn {field, {msg, _}} -> {field, msg} end)
  end
end
