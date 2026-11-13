defmodule Portermills.EmailInvitesTest do
  use Portermills.DataCase, async: true

  alias Phoenix.Socket.Broadcast
  alias Portermills.Calendar.Event
  alias Portermills.EmailInvites

  setup do
    family = family_fixture()
    user = user_fixture(family, %{name: "Mum", email: "Mum@Gmail.com"})
    PortermillsWeb.Endpoint.subscribe("family:#{family.id}:calendar")
    %{family: family, user: user}
  end

  defp email(calendars, opts \\ []) do
    %{
      from: Keyword.get(opts, :from, "mum@gmail.com"),
      authentication_results: Keyword.get(opts, :auth, [passing_auth_results("gmail.com")]),
      calendars: List.wrap(calendars)
    }
  end

  test "adds an invite from a family member to their family's calendar", %{
    family: family,
    user: user
  } do
    ics =
      invite_ics(extra: ["LOCATION:Main hall", "DESCRIPTION:Bring flowers", "RRULE:FREQ=YEARLY"])

    assert {:ok, [{:created, event}]} = EmailInvites.import_email(email(ics))

    assert %Event{
             title: "School play",
             description: "Location: Main hall\n\nBring flowers",
             starts_at: ~U[2026-11-20 19:00:00Z],
             ends_at: ~U[2026-11-20 21:00:00Z],
             all_day: false,
             recurrence_rule: "FREQ=YEARLY",
             ical_uid: "abc-123@example.com",
             family_id: family_id,
             created_by_id: created_by_id
           } = Repo.get!(Event, event.id)

    assert family_id == family.id
    assert created_by_id == user.id

    assert_receive %Broadcast{event: "calendar:event_created", payload: %{event: %Event{id: id}}}
    assert id == event.id
  end

  test "the broadcast payload encodes to JSON for clients" do
    {:ok, [{:created, event}]} = EmailInvites.import_email(email(invite_ics()))
    json = event |> Jason.encode!() |> Jason.decode!()

    assert json["title"] == "School play"
    assert json["starts_at"] == "2026-11-20T19:00:00Z"
    refute Map.has_key?(json, "ical_uid")
  end

  test "rejects mail from people outside the family" do
    assert {:rejected, :sender_not_family_member} =
             EmailInvites.import_email(email(invite_ics(), from: "stranger@gmail.com"))

    assert Repo.aggregate(Event, :count) == 0
  end

  test "rejects mail whose From is not authenticated" do
    forged =
      "mx1.messagingengine.com; dkim=pass header.d=attacker.test; dmarc=fail header.from=gmail.com"

    assert {:rejected, :sender_not_authenticated} =
             EmailInvites.import_email(email(invite_ics(), auth: [forged]))

    assert Repo.aggregate(Event, :count) == 0
  end

  test "an updated invite updates the existing event instead of duplicating it" do
    {:ok, [{:created, original}]} = EmailInvites.import_email(email(invite_ics()))

    updated_ics =
      invite_ics(
        sequence: 1,
        summary: "School play (moved)",
        dtstart: "DTSTART:20261121T190000Z",
        dtend: "DTEND:20261121T210000Z"
      )

    assert {:ok, [{:updated, updated}]} = EmailInvites.import_email(email(updated_ics))
    assert updated.id == original.id
    assert updated.title == "School play (moved)"
    assert updated.starts_at == ~U[2026-11-21 19:00:00Z]
    assert updated.created_by_id == original.created_by_id
    assert Repo.aggregate(Event, :count) == 1
    assert_receive %Broadcast{event: "calendar:event_updated"}
  end

  test "an older copy of an invite does not overwrite a newer one" do
    {:ok, [{:created, _}]} =
      EmailInvites.import_email(email(invite_ics(sequence: 3, summary: "Newest")))

    assert {:ok, [{:skipped, :outdated_invite}]} =
             EmailInvites.import_email(email(invite_ics(sequence: 1, summary: "Older")))

    assert [%Event{title: "Newest"}] = Repo.all(Event)
  end

  test "a cancellation removes the event" do
    {:ok, [{:created, event}]} = EmailInvites.import_email(email(invite_ics()))

    assert {:ok, [{:deleted, _}]} =
             EmailInvites.import_email(email(invite_ics(method: "CANCEL", sequence: 1)))

    refute Repo.get(Event, event.id)
    assert_receive %Broadcast{event: "calendar:event_deleted", payload: %{event: %{id: id}}}
    assert id == event.id
  end

  test "a cancellation for an unknown event is a no-op" do
    assert {:ok, [{:skipped, :cancelled_event_not_found}]} =
             EmailInvites.import_email(email(invite_ics(method: "CANCEL")))
  end

  test "the same invite UID is tracked separately per family", %{family: family} do
    other_family = family_fixture("Neighbours")
    user_fixture(other_family, %{email: "neighbour@gmail.com"})

    {:ok, [{:created, ours}]} = EmailInvites.import_email(email(invite_ics()))

    {:ok, [{:created, theirs}]} =
      EmailInvites.import_email(email(invite_ics(), from: "neighbour@gmail.com"))

    assert ours.family_id == family.id
    assert theirs.family_id == other_family.id

    {:ok, [{:deleted, _}]} =
      EmailInvites.import_email(email(invite_ics(method: "CANCEL"), from: "neighbour@gmail.com"))

    assert Repo.get(Event, ours.id)
    refute Repo.get(Event, theirs.id)
  end

  test "skips replies, occurrence overrides and non-calendar attachments" do
    override =
      invite_ics(uid: "series-1", extra: ["RECURRENCE-ID:20261127T190000Z"])

    assert {:ok, outcomes} =
             EmailInvites.import_email(
               email([invite_ics(method: "REPLY"), override, "not a calendar"])
             )

    assert outcomes == [
             {:skipped, {:unsupported_method, "REPLY"}},
             {:skipped, :single_occurrence_change},
             {:skipped, :not_icalendar}
           ]

    assert Repo.aggregate(Event, :count) == 0
  end

  test "imports invites published without a METHOD or UID" do
    ics =
      "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20261224\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

    assert {:ok, [{:created, event}]} = EmailInvites.import_email(email(ics))
    assert event.title == "(No title)"
    assert event.all_day
    assert event.ical_uid == nil
  end

  test "truncates titles that don't fit the column" do
    {:ok, [{:created, event}]} =
      EmailInvites.import_email(email(invite_ics(summary: String.duplicate("a", 300))))

    assert String.length(event.title) == 255
  end
end
