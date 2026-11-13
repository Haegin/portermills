defmodule Portermills.EmailInvites.DKIMTest do
  use ExUnit.Case, async: true

  import Portermills.EmailInviteFixtures, only: [email: 1]

  alias Portermills.EmailInvites.{DKIM, RawEmail}

  defp verify(raw, domain \\ "family.example"), do: DKIM.verify(RawEmail.parse(raw), domain)

  describe "signatures made by dkimpy" do
    test "relaxed/relaxed, with forwarding headers added on top" do
      assert :ok = verify(email("gmail_style"))
    end

    test "simple/simple" do
      assert :ok = verify(email("outlook_style"))
    end

    test "relaxed/simple" do
      assert :ok = verify(email("forwarded_as_attachment"))
    end

    test "survive LF-only line endings (normalised back to CRLF)" do
      assert :ok = verify(String.replace(email("gmail_style"), "\r\n", "\n"))
    end

    test "a subdomain sender is aligned with its parent domain's signature" do
      assert :ok = verify(email("gmail_style"), "mail.family.example")

      assert {:error, [{"family.example", :not_aligned_with_from}]} =
               verify(email("gmail_style"), "notfamily.example")
    end
  end

  describe "rejects" do
    test "a valid signature from a domain unrelated to the sender" do
      assert {:error, [{"attacker.example", :not_aligned_with_from}]} =
               verify(email("unaligned_signature"))
    end

    test "a modified body" do
      tampered =
        String.replace(email("gmail_style"), "Swimming gala   with", "Swimming GALA   with")

      assert {:error, [{"family.example", :body_hash_mismatch}]} = verify(tampered)
    end

    test "a modified signed header" do
      tampered = String.replace(email("gmail_style"), "From: Mum <", "From: Mallory <")
      assert {:error, [{"family.example", :bad_signature}]} = verify(tampered)
    end

    test "a modified signature" do
      raw = email("outlook_style")
      [_, b] = Regex.run(~r/ b=([A-Za-z0-9+\/]{10})/, raw)
      tampered = String.replace(raw, " b=" <> b, " b=" <> String.reverse(b))
      assert {:error, [{"family.example", :bad_signature}]} = verify(tampered)
    end

    test "an unsigned message" do
      unsigned = Regex.replace(~r/DKIM-Signature:.*?\r\n(?=\S)/s, email("outlook_style"), "")
      refute unsigned =~ "DKIM-Signature"
      assert {:error, [:no_signature]} = verify(unsigned)
    end

    test "a signature whose key is not in DNS" do
      raw = String.replace(email("outlook_style"), "s=sel1;", "s=gone;")
      assert {:error, [{"family.example", :no_key_in_dns}]} = verify(raw)
    end

    test "weak or partial signatures, before checking any crypto" do
      raw = email("outlook_style")

      assert {:error, [{_, {:unsupported_algorithm, "rsa-sha1"}}]} =
               verify(String.replace(raw, "a=rsa-sha256", "a=rsa-sha1"))

      assert {:error, [{_, :partial_body_signature}]} =
               verify(String.replace(raw, "a=rsa-sha256;", "a=rsa-sha256; l=10;"))

      assert {:error, [{_, :expired}]} =
               verify(String.replace(raw, "a=rsa-sha256;", "a=rsa-sha256; x=1000000000;"))

      assert {:error, [{_, :from_not_signed}]} =
               verify(String.replace(raw, "h=from : to :", "h=to :"))
    end

    test "malformed signatures" do
      raw = String.replace(email("outlook_style"), "bh=", "xx=")
      assert {:error, [{nil, :malformed_signature}]} = verify(raw)
    end
  end

  describe "body canonicalization (RFC 6376 §3.4.6 example)" do
    @body " C \r\nD \t E\r\n\r\n\r\n"

    test "relaxed" do
      assert DKIM.canonical_body(@body, "relaxed") == " C\r\nD E\r\n"
      assert DKIM.canonical_body("", "relaxed") == ""
      assert DKIM.canonical_body("\r\n\r\n", "relaxed") == ""
    end

    test "simple" do
      assert DKIM.canonical_body(@body, "simple") == " C \r\nD \t E\r\n"
      assert DKIM.canonical_body("", "simple") == "\r\n"
      assert DKIM.canonical_body("no newline", "simple") == "no newline\r\n"
    end
  end
end
