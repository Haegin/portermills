defmodule Portermills.EmailInvites.PollerTest do
  # Not async: Req.Test stubs and the SQL sandbox are shared with the test process.
  use Portermills.DataCase

  import ExUnit.CaptureLog

  alias Portermills.Calendar.Event
  alias Portermills.EmailInvites.{Fastmail, Poller}

  @api "https://api.fastmail.test/jmap/api/"
  @download "https://files.fastmail.test/jmap/download/{accountId}/{blobId}/{name}?type={type}"
  @settings %{token: "fm-token", address: "app@portermills.net"}

  setup do
    family = family_fixture()
    user_fixture(family, %{name: "Mum", email: "mum@gmail.com"})
    {:ok, agent} = Agent.start_link(fn -> [] end)
    %{family: family, requests: agent}
  end

  # A fake Fastmail: serves the given emails and blobs and records every JMAP call.
  defp stub_fastmail(requests, emails, blobs, opts \\ []) do
    Req.Test.stub(Fastmail, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer fm-token"]

      case {conn.method, conn.host, conn.request_path} do
        {"GET", "api.fastmail.com", "/jmap/session"} ->
          Req.Test.json(conn, %{
            "apiUrl" => @api,
            "downloadUrl" => @download,
            "primaryAccounts" => %{"urn:ietf:params:jmap:mail" => "u123"}
          })

        {"POST", "api.fastmail.test", "/jmap/api/"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          %{"methodCalls" => calls} = Jason.decode!(body)
          Agent.update(requests, &(&1 ++ calls))
          Req.Test.json(conn, %{"methodResponses" => Enum.flat_map(calls, &respond(&1, emails))})

        {"GET", "files.fastmail.test", "/jmap/download/u123/" <> rest} ->
          [blob_id | _] = String.split(rest, "/")

          if blob_id in Keyword.get(opts, :failing_blobs, []) do
            Plug.Conn.send_resp(conn, 503, "unavailable")
          else
            Plug.Conn.send_resp(conn, 200, Map.fetch!(blobs, blob_id))
          end
      end
    end)
  end

  defp respond(["Mailbox/get", _args, id], _emails) do
    [
      [
        "Mailbox/get",
        %{
          "list" => [
            %{"id" => "inbox", "role" => "inbox"},
            %{"id" => "sent", "role" => "sent"},
            %{"id" => "trash", "role" => "trash"},
            %{"id" => "invites", "role" => nil}
          ]
        },
        id
      ]
    ]
  end

  defp respond(["Email/query", _args, id], emails),
    do: [["Email/query", %{"ids" => Enum.map(emails, & &1["id"])}, id]]

  defp respond(["Email/get", _args, id], emails), do: [["Email/get", %{"list" => emails}, id]]

  defp respond(["Email/set", %{"update" => update}, id], _emails),
    do: [
      [
        "Email/set",
        %{"updated" => Map.new(update, fn {k, _} -> {k, nil} end), "notUpdated" => %{}},
        id
      ]
    ]

  defp jmap_email(id, from, parts, auth \\ nil) do
    %{
      "id" => id,
      "from" => [%{"name" => "Someone", "email" => from}],
      "subject" => "Invitation: School play",
      "header:Authentication-Results:asText:all" => [auth || passing_auth_results(domain(from))],
      "bodyStructure" => %{
        "type" => "multipart/mixed",
        "subParts" => [
          %{
            "type" => "multipart/alternative",
            "subParts" =>
              [%{"partId" => "1", "blobId" => "text-#{id}", "type" => "text/plain"}] ++ parts
          }
        ]
      }
    }
  end

  defp domain(address), do: address |> String.split("@") |> List.last()

  defp calls(requests, name), do: requests |> Agent.get(& &1) |> Enum.filter(&(hd(&1) == name))

  defp marked_ids(requests) do
    requests
    |> calls("Email/set")
    |> Enum.flat_map(fn [_, %{"update" => u}, _] -> Map.keys(u) end)
  end

  test "imports invites, tags every finished email, and leaves failures for retry", %{
    family: family,
    requests: requests
  } do
    gmail_parts = [
      # Gmail attaches the same invite inline and as invite.ics; they share a blob.
      %{"partId" => "2", "blobId" => "invite-blob", "type" => "text/calendar", "name" => nil},
      %{
        "partId" => "3",
        "blobId" => "invite-blob",
        "type" => "application/ics",
        "name" => "invite.ics"
      }
    ]

    emails = [
      jmap_email("m-invite", "mum@gmail.com", gmail_parts),
      jmap_email("m-stranger", "stranger@gmail.com", [
        %{"partId" => "2", "blobId" => "stranger-blob", "type" => "text/calendar"}
      ]),
      jmap_email("m-plain", "mum@gmail.com", []),
      jmap_email("m-flaky", "mum@gmail.com", [
        %{
          "partId" => "2",
          "blobId" => "flaky-blob",
          "type" => "application/octet-stream",
          "name" => "Party.ICS"
        }
      ])
    ]

    blobs = %{"invite-blob" => invite_ics(), "stranger-blob" => invite_ics(uid: "spam")}
    stub_fastmail(requests, emails, blobs, failing_blobs: ["flaky-blob"])

    log = capture_log(fn -> assert {:ok, 3} = Poller.poll_once(@settings) end)

    assert [%Event{title: "School play", family_id: family_id}] = Repo.all(Event)
    assert family_id == family.id

    assert Enum.sort(marked_ids(requests)) == ["m-invite", "m-plain", "m-stranger"]
    assert log =~ "sender_not_family_member"
    assert log =~ "could not download attachments of m-flaky"

    # The query only asks for unprocessed mail to the invite address, outside Sent/Trash.
    [[_, %{"filter" => %{"conditions" => conditions}}, _]] = calls(requests, "Email/query")

    assert %{
             "operator" => "OR",
             "conditions" => [%{"to" => "app@portermills.net"}, %{"cc" => "app@portermills.net"}]
           } in conditions

    assert %{"notKeyword" => "portermills_imported"} in conditions
    assert %{"inMailboxOtherThan" => ["sent", "trash"]} in conditions

    [[_, %{"update" => update}, _]] = calls(requests, "Email/set")
    assert update["m-invite"] == %{"keywords/portermills_imported" => true}
  end

  test "does nothing when there is no new mail", %{requests: requests} do
    stub_fastmail(requests, [], %{})
    assert {:ok, 0} = Poller.poll_once(@settings)
    assert calls(requests, "Email/set") == []
  end

  test "reports connection failures without crashing", %{requests: _requests} do
    Req.Test.stub(Fastmail, &Plug.Conn.send_resp(&1, 401, "unauthorized"))
    assert {:error, {:http_status, 401}} = Poller.poll_once(@settings)
  end

  test "surfaces JMAP method errors", %{requests: _requests} do
    Req.Test.stub(Fastmail, fn conn ->
      case conn.method do
        "GET" ->
          Req.Test.json(conn, %{
            "apiUrl" => @api,
            "downloadUrl" => @download,
            "primaryAccounts" => %{"urn:ietf:params:jmap:mail" => "u123"}
          })

        "POST" ->
          Req.Test.json(conn, %{"methodResponses" => [["error", %{"type" => "forbidden"}, "m"]]})
      end
    end)

    assert {:error, {:jmap, "m", %{"type" => "forbidden"}}} = Poller.poll_once(@settings)
  end
end
