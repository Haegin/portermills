defmodule PortermillsWeb.FallbackController do
  use Phoenix.Controller, formats: [:json]

  def call(conn, nil), do: call(conn, {:error, :not_found})

  def call(conn, {:error, :not_found}) do
    conn |> put_status(:not_found) |> json(%{error: "not found"})
  end

  def call(conn, {:error, :forbidden}) do
    conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
  end

  def call(conn, {:error, :already_claimed}) do
    conn |> put_status(:conflict) |> json(%{error: "already claimed"})
  end

  def call(conn, {:error, :bad_request}) do
    conn |> put_status(:bad_request) |> json(%{error: "bad request"})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
