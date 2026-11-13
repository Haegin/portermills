defmodule Portermills.EmailInvitesTest do
  use Portermills.DataCase, async: true

  import Portermills.EmailInviteFixtures, only: [email: 1]

  alias Phoenix.Socket.Broadcast
  alias Portermills.Calendar.Event
  alias Portermills.EmailInvites

  setup do
    family = family_fixture()
    # Stored with different case than the emails use; matching ignores case.
    mum = user_fixture(family, %{name: "Mum", email: "Mum@Family.example"})
    dad = user_fixture(family, %{name: "Dad", email: "dad@family.example"})
    PortermillsWeb.Endpoint.subscribe("family:#{family.id}:calendar")
    %{family: family, mum: mum, dad: dad}
  end

  describe "import_email/1 (raw, DKIM-signed emails)" do
    test "adds a forwarded Gmail invite to the sender's family calendar", %{
      family: family,
      mum: mum
    } do
      assert {:ok, [{:created, event}]} = EmailInvites.import_email(email("gmail_style"))

      assert %Event{
               title: "Swimming gala",
               description: "Location: Leisure centre, Pool 2\n\nBring goggles and a towel.",
               # 2pm Europe/London in December is 14:00 UTC.
               starts_at: ~U[2026-12-05 14:00:00Z],
               ends_at: ~U[2026-12-05 16:00:00Z],
               all_day: false,
               ical_uid: "5q3n0v9ld0kq8m2kj1b6fhd7c4@google.com"
             } = Repo.get!(Event, event.id)

      assert event.family_id == family.id
      assert event.created_by_id == mum.id

      assert_receive %Broadcast{
        event: "calendar:event_created",
        payload: %{event: %Event{id: id}}
      }

      assert id == event.id
    end

    test "adds an Outlook invite with a Windows timezone", %{dad: dad} do
      assert {:ok, [{:created, event}]} = EmailInvites.import_email(email("outlook_style"))
      assert event.title == "End of term assembly"
      assert event.starts_at == ~U[2026-12-18 09:15:00Z]
      assert event.ends_at == ~U[2026-12-18 10:30:00Z]
      assert event.created_by_id == dad.id
    end

    test "adds an invite forwarded as an attachment" do
      assert {:ok, [{:created, event}]} =
               EmailInvites.import_email(email("forwarded_as_attachment"))

      assert event.title == "Christmas at Gran's"
      assert event.all_day

      assert {event.starts_at, event.ends_at} ==
               {~U[2026-12-24 00:00:00Z], ~U[2026-12-27 00:00:00Z]}
    end

    test "importing the same email twice keeps one event" do
      {:ok, [{:created, event}]} = EmailInvites.import_email(email("gmail_style"))
      assert {:ok, [{:updated, %{id: id}}]} = EmailInvites.import_email(email("gmail_style"))
      assert id == event.id
      assert Repo.aggregate(Event, :count) == 1
    end

    test "rejects mail from people outside the family", %{dad: dad} do
      Repo.delete!(dad)

      assert {:rejected, :sender_not_family_member} =
               EmailInvites.import_email(email("outlook_style"))

      assert Repo.aggregate(Event, :count) == 0
    end

    test "rejects a forged From: (signed by another domain)" do
      assert {:rejected,
              {:sender_not_authenticated, [{"attacker.example", :not_aligned_with_from}]}} =
               EmailInvites.import_email(email("unaligned_signature"))

      assert Repo.aggregate(Event, :count) == 0
    end

    test "rejects an email altered after signing" do
      tampered =
        String.replace(email("outlook_style"), "Forwarding the assembly invite.", "Forwarding.")

      assert {:rejected, {:sender_not_authenticated, [{"family.example", :body_hash_mismatch}]}} =
               EmailInvites.import_email(tampered)
    end

    test "rejects emails with an ambiguous sender" do
      raw = "From: mum@family.example\r\n" <> email("gmail_style")
      assert {:rejected, :multiple_from_headers} = EmailInvites.import_email(raw)
    end

    test "accepts verified mail with no invite in it" do
      assert {:ok, []} = EmailInvites.import_email(email("no_invite"))
      assert Repo.aggregate(Event, :count) == 0
    end
  end

  describe "import_calendar/2" do
    test "creates events with the invite's details", %{family: family, mum: mum} do
      ics =
        invite_ics(
          extra: ["LOCATION:Main hall", "DESCRIPTION:Bring flowers", "RRULE:FREQ=YEARLY"]
        )

      assert [{:created, event}] = EmailInvites.import_calendar(ics, mum)

      assert %Event{
               title: "School play",
               description: "Location: Main hall\n\nBring flowers",
               starts_at: ~U[2026-11-20 19:00:00Z],
               ends_at: ~U[2026-11-20 21:00:00Z],
               recurrence_rule: "FREQ=YEARLY",
               ical_uid: "abc-123@example.com",
               ical_sequence: 0
             } = event

      assert event.family_id == family.id
    end

    test "the broadcast payload encodes to JSON for clients", %{mum: mum} do
      [{:created, event}] = EmailInvites.import_calendar(invite_ics(), mum)
      json = event |> Jason.encode!() |> Jason.decode!()

      assert json["title"] == "School play"
      assert json["starts_at"] == "2026-11-20T19:00:00Z"
      refute Map.has_key?(json, "ical_uid")
    end

    test "an updated invite updates the existing event", %{mum: mum, dad: dad} do
      [{:created, original}] = EmailInvites.import_calendar(invite_ics(), mum)

      updated_ics =
        invite_ics(
          sequence: 1,
          summary: "School play (moved)",
          dtstart: "DTSTART:20261121T190000Z",
          dtend: "DTEND:20261121T210000Z"
        )

      # Anyone in the family can forward the update.
      assert [{:updated, updated}] = EmailInvites.import_calendar(updated_ics, dad)
      assert updated.id == original.id
      assert updated.title == "School play (moved)"
      assert updated.starts_at == ~U[2026-11-21 19:00:00Z]
      assert updated.created_by_id == mum.id
      assert Repo.aggregate(Event, :count) == 1
      assert_receive %Broadcast{event: "calendar:event_updated"}
    end

    test "an older copy of an invite does not overwrite a newer one", %{mum: mum} do
      [{:created, _}] =
        EmailInvites.import_calendar(invite_ics(sequence: 3, summary: "Newest"), mum)

      assert [{:skipped, :outdated_invite}] =
               EmailInvites.import_calendar(invite_ics(sequence: 1, summary: "Older"), mum)

      assert [%Event{title: "Newest"}] = Repo.all(Event)
    end

    test "a cancellation removes the event", %{mum: mum} do
      [{:created, event}] = EmailInvites.import_calendar(invite_ics(), mum)

      assert [{:deleted, _}] =
               EmailInvites.import_calendar(invite_ics(method: "CANCEL", sequence: 1), mum)

      refute Repo.get(Event, event.id)
      assert_receive %Broadcast{event: "calendar:event_deleted", payload: %{event: %{id: id}}}
      assert id == event.id
    end

    test "a cancellation for an unknown event is a no-op", %{mum: mum} do
      assert [{:skipped, :cancelled_event_not_found}] =
               EmailInvites.import_calendar(invite_ics(method: "CANCEL"), mum)
    end

    test "the same invite UID is tracked separately per family", %{family: family, mum: mum} do
      other_family = family_fixture("Neighbours")
      neighbour = user_fixture(other_family, %{email: "neighbour@elsewhere.example"})

      [{:created, ours}] = EmailInvites.import_calendar(invite_ics(), mum)
      [{:created, theirs}] = EmailInvites.import_calendar(invite_ics(), neighbour)

      assert ours.family_id == family.id
      assert theirs.family_id == other_family.id

      [{:deleted, _}] = EmailInvites.import_calendar(invite_ics(method: "CANCEL"), neighbour)

      assert Repo.get(Event, ours.id)
      refute Repo.get(Event, theirs.id)
    end

    test "skips replies, occurrence overrides and non-calendar data", %{mum: mum} do
      override = invite_ics(uid: "series-1", extra: ["RECURRENCE-ID:20261127T190000Z"])

      outcomes =
        Enum.flat_map(
          [invite_ics(method: "REPLY"), override, "not a calendar"],
          &EmailInvites.import_calendar(&1, mum)
        )

      assert outcomes == [
               {:skipped, {:unsupported_method, "REPLY"}},
               {:skipped, :single_occurrence_change},
               {:skipped, :not_icalendar}
             ]

      assert Repo.aggregate(Event, :count) == 0
    end

    test "imports invites published without a METHOD or UID", %{mum: mum} do
      ics =
        "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20261224\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

      assert [{:created, event}] = EmailInvites.import_calendar(ics, mum)
      assert event.title == "(No title)"
      assert event.all_day
      assert event.ical_uid == nil
    end

    test "truncates titles that don't fit the column", %{mum: mum} do
      [{:created, event}] =
        EmailInvites.import_calendar(invite_ics(summary: String.duplicate("a", 300)), mum)

      assert String.length(event.title) == 255
    end
  end
end
