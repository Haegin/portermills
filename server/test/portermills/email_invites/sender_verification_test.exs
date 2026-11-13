defmodule Portermills.EmailInvites.SenderVerificationTest do
  use ExUnit.Case, async: true

  import Portermills.DataCase, only: [passing_auth_results: 1]

  alias Portermills.EmailInvites.SenderVerification

  @suffix "messagingengine.com"

  defp verify(from, headers), do: SenderVerification.verify(from, headers, @suffix)

  test "accepts mail that passed DMARC and DKIM for the From domain" do
    assert :ok = verify("mum@gmail.com", [passing_auth_results("gmail.com")])
  end

  test "is case-insensitive about the address" do
    assert :ok = verify("Mum@GMail.com", [passing_auth_results("gmail.com")])
  end

  test "accepts DMARC pass on its own" do
    header = "mx2.messagingengine.com; dkim=none; dmarc=pass (p=reject) header.from=example.org"
    assert :ok = verify("dad@example.org", [header])
  end

  test "accepts an aligned DKIM signature without DMARC" do
    header =
      "mx2.messagingengine.com; dkim=pass header.d=example.org; dmarc=none header.from=mail.example.org"

    assert :ok = verify("dad@mail.example.org", [header])
  end

  test "rejects a DKIM signature from an unrelated domain (forged From)" do
    header =
      "mx2.messagingengine.com; dkim=pass header.d=attacker.test; " <>
        "dmarc=fail (p=none) header.from=gmail.com; spf=pass smtp.mailfrom=attacker.test"

    assert {:rejected, :sender_not_authenticated} = verify("mum@gmail.com", [header])
  end

  test "rejects failures and lookalike domains" do
    assert {:rejected, :sender_not_authenticated} =
             verify("mum@gmail.com", [
               "mx1.messagingengine.com; dkim=fail header.d=gmail.com; dmarc=fail header.from=gmail.com"
             ])

    assert {:rejected, :sender_not_authenticated} =
             verify("mum@gmail.com", [passing_auth_results("notgmail.com")])
  end

  test "ignores properties written inside comments" do
    header = "mx1.messagingengine.com; dkim=pass (header.d=gmail.com) header.d=attacker.test"
    assert {:rejected, :sender_not_authenticated} = verify("mum@gmail.com", [header])
  end

  test "only trusts the topmost header, which the receiving server added" do
    forged = passing_auth_results("gmail.com")
    real = "mx1.messagingengine.com; dkim=none; dmarc=fail header.from=gmail.com"

    assert {:rejected, :sender_not_authenticated} = verify("mum@gmail.com", [real, forged])
  end

  test "rejects headers not written by the trusted mail server" do
    header =
      String.replace(passing_auth_results("gmail.com"), "mx4.messagingengine.com", "mx.evil.test")

    assert {:rejected, :untrusted_authentication_results} = verify("mum@gmail.com", [header])

    header =
      String.replace(
        passing_auth_results("gmail.com"),
        "mx4.messagingengine.com",
        "evilmessagingengine.com"
      )

    assert {:rejected, :untrusted_authentication_results} = verify("mum@gmail.com", [header])
  end

  test "rejects mail without Authentication-Results or a valid From" do
    assert {:rejected, :no_authentication_results} = verify("mum@gmail.com", [])

    assert {:rejected, :invalid_from_address} =
             verify("not-an-address", [passing_auth_results("gmail.com")])
  end
end
