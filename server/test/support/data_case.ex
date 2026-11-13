defmodule Portermills.DataCase do
  @moduledoc "Test case for tests that touch the database (runs in an SQL sandbox)."

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Portermills.Repo
      import Ecto.Query
      import Portermills.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Portermills.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  alias Portermills.Repo
  alias Portermills.Accounts.{Family, User}

  def family_fixture(name \\ "Porter Mills") do
    %Family{} |> Family.changeset(%{name: name}) |> Repo.insert!()
  end

  def user_fixture(family, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Member",
        email: "member#{System.unique_integer([:positive])}@example.com",
        family_id: family.id
      })

    %User{} |> User.changeset(attrs) |> Repo.insert!()
  end

  @doc "An Authentication-Results header as Fastmail writes it, passing DKIM and DMARC."
  def passing_auth_results(domain) do
    "mx4.messagingengine.com; dkim=pass (2048-bit rsa key sha256) header.d=#{domain} " <>
      "header.i=@#{domain} header.b=AbCdEf header.a=rsa-sha256 header.s=s1 x-bits=2048; " <>
      "dmarc=pass policy.published-domain-policy=none (p=none,d=none,d.eval=none) " <>
      "policy.policy-from=p header.from=#{domain}; spf=pass smtp.mailfrom=bounce@#{domain}"
  end

  @doc "Builds a minimal invite. `props` are raw VEVENT lines added after the defaults."
  def invite_ics(opts \\ []) do
    method = Keyword.get(opts, :method, "REQUEST")
    uid = Keyword.get(opts, :uid, "abc-123@example.com")
    sequence = Keyword.get(opts, :sequence, 0)
    summary = Keyword.get(opts, :summary, "School play")
    dtstart = Keyword.get(opts, :dtstart, "DTSTART:20261120T190000Z")
    dtend = Keyword.get(opts, :dtend, "DTEND:20261120T210000Z")

    Enum.join(
      [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Test//Test//EN",
        "METHOD:#{method}",
        "BEGIN:VEVENT",
        "UID:#{uid}",
        "SEQUENCE:#{sequence}",
        "SUMMARY:#{summary}",
        dtstart,
        dtend
      ] ++ Keyword.get(opts, :extra, []) ++ ["END:VEVENT", "END:VCALENDAR", ""],
      "\r\n"
    )
  end
end
