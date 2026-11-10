defmodule Portermills.AccountsTest do
  use Portermills.DataCase, async: true
  import Swoosh.TestAssertions

  alias Portermills.Accounts
  alias Portermills.Accounts.MagicToken

  setup do
    family = family_fixture()
    %{family: family, user: user_fixture(family, %{email: "Alex@Example.com"})}
  end

  test "emails are stored lowercased and looked up case-insensitively", %{user: user} do
    assert user.email == "alex@example.com"
    assert Accounts.get_user_by_email(" ALEX@example.com ").id == user.id
  end

  test "emails are unique", %{family: family} do
    assert {:error, changeset} = Accounts.create_user(family, %{name: "Dup", email: "alex@example.com"})
    assert "has already been taken" in errors_on(changeset).email
  end

  test "a magic token signs in once", %{user: user} do
    assert {:ok, _user, token} = Accounts.create_magic_token(user.email)
    assert {:ok, verified} = Accounts.verify_magic_token(token)
    assert verified.id == user.id
    assert {:error, :invalid_token} = Accounts.verify_magic_token(token)
  end

  test "the raw token is not stored", %{user: user} do
    {:ok, _user, token} = Accounts.create_magic_token(user.email)
    refute Repo.get_by(MagicToken, token: token)
  end

  test "an expired token is rejected", %{user: user} do
    {:ok, _user, token} = Accounts.create_magic_token(user.email)
    Repo.update_all(MagicToken, set: [expires_at: ~U[2020-01-01 00:00:00Z]])
    assert {:error, :invalid_token} = Accounts.verify_magic_token(token)
  end

  test "unknown tokens and emails are rejected" do
    assert {:error, :invalid_token} = Accounts.verify_magic_token("nope")
    assert {:error, :invalid_token} = Accounts.verify_magic_token(nil)
    assert {:error, :not_found} = Accounts.create_magic_token("nobody@example.com")
  end

  test "deliver_magic_link/2 emails a link containing the token", %{user: user} do
    assert :ok = Accounts.deliver_magic_link(user.email, &("https://example.test/auth/magic/" <> &1))

    assert_email_sent(fn email ->
      assert email.to == [{user.name, user.email}]
      assert [_, token] = Regex.run(~r{https://example.test/auth/magic/(\S+)}, email.text_body)
      assert {:ok, _} = Accounts.verify_magic_token(token)
    end)
  end

  test "deliver_magic_link/2 sends nothing for an unknown email" do
    assert {:error, :not_found} = Accounts.deliver_magic_link("nobody@example.com", & &1)
    assert_no_email_sent()
  end

  test "list_family_members/1 only returns that family", %{family: family, user: user} do
    _outsider = user_fixture(family_fixture())
    assert [member] = Accounts.list_family_members(family.id)
    assert member.id == user.id
  end
end
