defmodule Portermills.EmailInvites.MIMETest do
  use ExUnit.Case, async: true

  import Portermills.EmailInviteFixtures, only: [email: 1]

  alias Portermills.EmailInvites.{MIME, RawEmail}

  defp parts(raw), do: raw |> RawEmail.parse() |> MIME.calendar_parts()

  test "finds a Gmail invite once, though it is both inline and attached" do
    assert [calendar] = parts(email("gmail_style"))
    assert calendar =~ "BEGIN:VCALENDAR"
    assert calendar =~ "SUMMARY:Swimming gala"
  end

  test "decodes quoted-printable Outlook invites" do
    assert [calendar] = parts(email("outlook_style"))
    assert calendar =~ "SUMMARY;LANGUAGE=en-GB:End of term assembly"
    assert calendar =~ "DTSTART;TZID=GMT Standard Time:20261218T091500"
    # Soft line break removed, iCalendar folding kept.
    assert calendar =~ "assembly. Ple\r\n ase arrive"
    refute calendar =~ "=3D"
  end

  test "finds invites inside a message forwarded as an attachment" do
    assert [calendar] = parts(email("forwarded_as_attachment"))
    assert calendar =~ "SUMMARY:Christmas at Gran's"
  end

  test "recognises .ics attachments by file name" do
    raw =
      Enum.join(
        [
          "Content-Type: multipart/mixed; boundary=b",
          "",
          "--b",
          "Content-Type: application/octet-stream",
          "Content-Disposition: attachment; filename=\"Party.ICS\"",
          "Content-Transfer-Encoding: base64",
          "",
          Base.encode64("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"),
          "--b--"
        ],
        "\r\n"
      )

    assert parts(raw) == ["BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"]
  end

  test "ignores mail without calendar parts" do
    assert parts("From: a@b.example\r\nSubject: hi\r\n\r\nJust text.\r\n") == []

    raw =
      "Content-Type: multipart/mixed; boundary=x\r\n\r\n--x\r\nContent-Type: text/plain\r\n\r\nhello\r\n--x--\r\n"

    assert parts(raw) == []
  end
end
