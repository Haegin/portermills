defmodule PortermillsWeb.PostmarkInboundControllerTest do
  # Not async: one test changes application config.
  use PortermillsWeb.ConnCase

  import ExUnit.CaptureLog
  import Portermills.EmailInviteFixtures, only: [email: 1]

  alias Portermills.Calendar.Event

  @path "/api/inbound/postmark"

  setup %{conn: conn} do
    family = family_fixture()
    user_fixture(family, %{name: "Mum", email: "mum@family.example"})

    authed =
      put_req_header(
        conn,
        "authorization",
        Plug.BasicAuth.encode_basic_auth("postmark", "test-webhook-secret")
      )

    %{conn: authed, unauthenticated: conn}
  end

  # Roughly what Postmark sends; we only rely on RawEmail.
  defp payload(raw) do
    %{
      "From" => "mum@family.example",
      "To" => "abc123@inbound.postmarkapp.com",
      "Subject" => "Fwd: Invitation: Swimming gala",
      "MessageID" => "22c74902-a0c1-4511-804f-341342852c90",
      "Headers" => [%{"Name" => "X-Spam-Status", "Value" => "No"}],
      "Attachments" => [],
      "RawEmail" => raw
    }
  end

  test "imports the invite in a Postmark inbound payload", %{conn: conn} do
    conn = post(conn, @path, payload(email("gmail_style")))
    assert json_response(conn, 200) == %{"status" => "processed"}

    assert [%Event{title: "Swimming gala"}] = Repo.all(Event)
  end

  test "answers 200 for rejected or invite-less emails, so Postmark doesn't retry", %{conn: conn} do
    log =
      capture_log(fn ->
        assert %{"status" => "rejected"} =
                 conn |> post(@path, payload(email("unaligned_signature"))) |> json_response(200)

        assert %{"status" => "no_invite"} =
                 conn |> post(@path, payload(email("no_invite"))) |> json_response(200)
      end)

    assert log =~ "not_aligned_with_from"
    assert Repo.aggregate(Event, :count) == 0
  end

  test "needs the raw email", %{conn: conn} do
    log =
      capture_log(fn ->
        conn = post(conn, @path, Map.delete(payload(""), "RawEmail"))
        assert json_response(conn, 422) == %{"error" => "RawEmail missing"}
      end)

    assert log =~ "Include raw email content"
  end

  test "requires the webhook credentials", %{unauthenticated: conn} do
    assert conn |> post(@path, payload(email("gmail_style"))) |> response(401)

    wrong =
      put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("postmark", "guess"))

    assert wrong |> post(@path, payload(email("gmail_style"))) |> response(401)

    assert Repo.aggregate(Event, :count) == 0
  end

  test "is disabled until credentials are configured", %{conn: conn} do
    config = Application.get_env(:portermills, PortermillsWeb.PostmarkInboundController)
    Application.delete_env(:portermills, PortermillsWeb.PostmarkInboundController)

    on_exit(fn ->
      Application.put_env(:portermills, PortermillsWeb.PostmarkInboundController, config)
    end)

    assert conn |> post(@path, payload(email("gmail_style"))) |> response(404)
  end

  test "accepts emails larger than the default 8 MB body limit", %{conn: conn} do
    # A big photo attachment alongside the invite (it lives in the signed body, so
    # pad with an unsigned header instead to keep the signature valid).
    big = "X-Padding: " <> String.duplicate("a", 10_000_000) <> "\r\n" <> email("gmail_style")
    body = Jason.encode!(payload(big))

    capture_log(fn ->
      conn = conn |> put_req_header("content-type", "application/json") |> post(@path, body)
      assert json_response(conn, 200) == %{"status" => "processed"}
    end)
  end
end
