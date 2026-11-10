defmodule PortermillsWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import PortermillsWeb.ChannelCase
      import Portermills.Fixtures

      @endpoint PortermillsWeb.Endpoint
    end
  end

  setup tags do
    Portermills.DataCase.setup_sandbox(tags)
    :ok
  end
end
