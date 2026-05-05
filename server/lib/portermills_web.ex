defmodule PortermillsWeb do
  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:json],
        layouts: []

      import Plug.Conn
      alias PortermillsWeb.Router.Helpers, as: Routes

      action_fallback PortermillsWeb.FallbackController
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {PortermillsWeb.Layouts, :app}
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
