defmodule PortermillsWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PortermillsWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import PortermillsWeb.ConnCase
      import Portermills.Fixtures
    end
  end

  setup tags do
    Portermills.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "A conn carrying a valid bearer token for `user`."
  def authed(conn, user) do
    {:ok, token, _claims} = Portermills.Guardian.encode_and_sign(user)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)
  end

  @doc "Two families: `user` and `other` in one, `stranger` in another."
  def two_families(_context \\ %{}) do
    family = Portermills.Fixtures.family_fixture("Ours")
    stranger_family = Portermills.Fixtures.family_fixture("Theirs")

    %{
      family: family,
      user: Portermills.Fixtures.user_fixture(family, %{name: "Alex"}),
      other: Portermills.Fixtures.user_fixture(family, %{name: "Sam"}),
      stranger: Portermills.Fixtures.user_fixture(stranger_family, %{name: "Stranger"})
    }
  end
end
