defmodule PortermillsWeb.ConnCase do
  @moduledoc "Test case for tests that go through the endpoint (with an SQL sandbox)."

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PortermillsWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Portermills.DataCase, except: [errors_on: 1]

      alias Portermills.Repo
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Portermills.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
