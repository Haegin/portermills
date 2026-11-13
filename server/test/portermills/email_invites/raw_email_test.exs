defmodule Portermills.EmailInvites.RawEmailTest do
  use ExUnit.Case, async: true

  alias Portermills.EmailInvites.RawEmail

  test "keeps raw header fields, folding included, and splits off the body" do
    message =
      RawEmail.parse(
        "Subject: a long\r\n  subject\r\nX-Empty:\r\nTo: app@portermills.net\r\n\r\nBody\r\n\r\nmore"
      )

    assert message.headers == [
             {"subject", "Subject: a long\r\n  subject"},
             {"x-empty", "X-Empty:"},
             {"to", "To: app@portermills.net"}
           ]

    assert message.body == "Body\r\n\r\nmore"
    assert RawEmail.values(message, "Subject") == ["a long  subject"]
  end

  test "normalises bare LF line endings" do
    message = RawEmail.parse("From: a@b.example\nSubject: x\n\nline 1\nline 2\n")
    assert message.body == "line 1\r\nline 2\r\n"
  end

  describe "from_address/1" do
    defp from(header), do: RawEmail.from_address(RawEmail.parse(header <> "\r\n\r\n"))

    test "reads the common forms" do
      assert from("From: mum@family.example") == {:ok, "mum@family.example"}
      assert from("From: Mum <Mum@Family.Example>") == {:ok, "mum@family.example"}
      assert from(~s(From: "Smith, Jo" <jo@family.example>)) == {:ok, "jo@family.example"}
      assert from("From: =?UTF-8?B?TXVt?= <mum@family.example>") == {:ok, "mum@family.example"}
    end

    test "refuses ambiguous senders" do
      assert from("From: a@x.example, b@y.example") == {:error, :multiple_from_addresses}
      assert from("From: <a@x.example>, <b@y.example>") == {:error, :multiple_from_addresses}
      assert from("From: a@x.example\r\nFrom: b@y.example") == {:error, :multiple_from_headers}
      assert from("To: a@x.example") == {:error, :no_from}
      assert from("From: nobody") == {:error, :invalid_from}
    end
  end
end
