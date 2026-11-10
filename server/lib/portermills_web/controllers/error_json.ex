defmodule PortermillsWeb.ErrorJSON do
  def render("404.json", _), do: %{error: "not found"}
  def render("500.json", _), do: %{error: "internal server error"}
  def render(template, _), do: %{error: Phoenix.Controller.status_message_from_template(template)}
end
