defmodule Portermills.EmailInvites.ICSTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Portermills.EmailInvites.ICS
  alias Portermills.EmailInvites.ICS.VEvent

  defp ics(lines), do: Enum.join(["BEGIN:VCALENDAR" | lines] ++ ["END:VCALENDAR", ""], "\r\n")

  defp parse_one(lines, opts \\ []) do
    assert {:ok, method, [event]} = ICS.parse(ics(lines), opts)
    {method, event}
  end

  test "parses a Google-style invite with UTC times" do
    {method, event} =
      parse_one([
        "METHOD:REQUEST",
        "BEGIN:VEVENT",
        "DTSTART:20261120T190000Z",
        "DTEND:20261120T210000Z",
        "UID:7kukuqrfedlm2f9t0vr42q7d9e@google.com",
        "SEQUENCE:2",
        "STATUS:CONFIRMED",
        "SUMMARY:School play",
        "LOCATION:Main hall\\, Hill School",
        "DESCRIPTION:Bring flowers\\nDoors open at 6:30",
        "RRULE:FREQ=WEEKLY;BYDAY=FR",
        "END:VEVENT"
      ])

    assert method == "REQUEST"

    assert %VEvent{
             uid: "7kukuqrfedlm2f9t0vr42q7d9e@google.com",
             sequence: 2,
             status: "CONFIRMED",
             title: "School play",
             location: "Main hall, Hill School",
             description: "Bring flowers\nDoors open at 6:30",
             all_day: false,
             recurrence_rule: "FREQ=WEEKLY;BYDAY=FR",
             recurrence_id: nil
           } = event

    assert event.starts_at == ~U[2026-11-20 19:00:00Z]
    assert event.ends_at == ~U[2026-11-20 21:00:00Z]
  end

  test "converts times with an IANA TZID to UTC, honouring daylight saving" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART;TZID=Europe/London:20260701T090000",
        "DTEND;TZID=\"America/New_York\":20260701T090000",
        "SUMMARY:Summer",
        "END:VEVENT"
      ])

    assert event.starts_at == ~U[2026-07-01 08:00:00Z]
    assert event.ends_at == ~U[2026-07-01 13:00:00Z]
  end

  test "maps Outlook's Windows timezone names" do
    {_method, event} =
      parse_one([
        "BEGIN:VTIMEZONE",
        "TZID:GMT Standard Time",
        "BEGIN:STANDARD",
        "DTSTART:16010101T020000",
        "TZOFFSETFROM:+0100",
        "TZOFFSETTO:+0000",
        "END:STANDARD",
        "END:VTIMEZONE",
        "BEGIN:VEVENT",
        "DTSTART;TZID=GMT Standard Time:20260601T100000",
        "DTEND;TZID=Pacific Standard Time:20260601T100000",
        "SUMMARY:Parents' evening",
        "END:VEVENT"
      ])

    assert event.starts_at == ~U[2026-06-01 09:00:00Z]
    assert event.ends_at == ~U[2026-06-01 17:00:00Z]
  end

  test "accepts Thunderbird's path-style TZIDs" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART;TZID=/mozilla.org/20050126_1/Europe/Paris:20260115T120000",
        "SUMMARY:Lunch",
        "END:VEVENT"
      ])

    assert event.starts_at == ~U[2026-01-15 11:00:00Z]
  end

  test "uses the default zone for floating times and unknown zones" do
    {_method, event} =
      parse_one(
        ["BEGIN:VEVENT", "DTSTART:20260115T120000", "SUMMARY:Floating", "END:VEVENT"],
        default_time_zone: "Europe/Paris"
      )

    assert event.starts_at == ~U[2026-01-15 11:00:00Z]

    log =
      capture_log(fn ->
        {_method, event} =
          parse_one(
            [
              "BEGIN:VEVENT",
              "DTSTART;TZID=Mars/Olympus:20260115T120000",
              "SUMMARY:?",
              "END:VEVENT"
            ],
            default_time_zone: "Europe/Paris"
          )

        assert event.starts_at == ~U[2026-01-15 11:00:00Z]
      end)

    assert log =~ "Unknown invite timezone"
  end

  test "parses all-day events with an exclusive end date" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART;VALUE=DATE:20261224",
        "DTEND;VALUE=DATE:20261227",
        "SUMMARY:Christmas at Gran's",
        "END:VEVENT"
      ])

    assert event.all_day
    assert event.starts_at == ~U[2026-12-24 00:00:00Z]
    assert event.ends_at == ~U[2026-12-27 00:00:00Z]
  end

  test "an all-day event without an end lasts one day" do
    {_method, event} =
      parse_one(["BEGIN:VEVENT", "DTSTART;VALUE=DATE:20261224", "SUMMARY:Eve", "END:VEVENT"])

    assert event.ends_at == ~U[2026-12-25 00:00:00Z]
  end

  test "computes the end from DURATION" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART:20261120T190000Z",
        "DURATION:PT1H30M",
        "SUMMARY:Swim",
        "END:VEVENT"
      ])

    assert event.ends_at == ~U[2026-11-20 20:30:00Z]
  end

  test "an event with neither DTEND nor DURATION ends when it starts" do
    {_method, event} =
      parse_one(["BEGIN:VEVENT", "DTSTART:20261120T190000Z", "SUMMARY:Reminder", "END:VEVENT"])

    assert event.ends_at == event.starts_at
  end

  test "unfolds long lines and handles colons inside quoted parameters" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART:20261120T190000Z",
        "SUMMARY:A very long title that",
        "  was folded",
        "ORGANIZER;CN=\"Smith: Jo\":mailto:jo@example.com",
        "DESCRIPTION:Line one\\nLine two",
        "\ttabbed continuation",
        "END:VEVENT"
      ])

    assert event.title == "A very long title that was folded"
    assert event.description == "Line one\nLine twotabbed continuation"
  end

  test "ignores properties of nested components like VALARM" do
    {_method, event} =
      parse_one([
        "BEGIN:VEVENT",
        "DTSTART:20261120T190000Z",
        "BEGIN:VALARM",
        "ACTION:DISPLAY",
        "DESCRIPTION:Reminder",
        "END:VALARM",
        "SUMMARY:Football",
        "END:VEVENT"
      ])

    assert event.title == "Football"
    assert event.description == nil
  end

  test "reads cancellations and occurrence overrides" do
    assert {:ok, "CANCEL", [master, override]} =
             ICS.parse(
               ics([
                 "METHOD:CANCEL",
                 "BEGIN:VEVENT",
                 "UID:u1",
                 "STATUS:CANCELLED",
                 "DTSTART:20261120T190000Z",
                 "END:VEVENT",
                 "BEGIN:VEVENT",
                 "UID:u1",
                 "RECURRENCE-ID:20261127T190000Z",
                 "DTSTART:20261127T200000Z",
                 "END:VEVENT"
               ])
             )

    assert master.status == "CANCELLED"
    assert master.recurrence_id == nil
    assert override.recurrence_id == "20261127T190000Z"
  end

  test "accepts bare LF line endings" do
    data =
      "BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20261120T190000Z\nSUMMARY:Unix\nEND:VEVENT\nEND:VCALENDAR\n"

    assert {:ok, nil, [%VEvent{title: "Unix"}]} = ICS.parse(data)
  end

  test "skips events with an unusable start time" do
    log =
      capture_log(fn ->
        assert {:ok, nil, [%VEvent{title: "Good"}]} =
                 ICS.parse(
                   ics([
                     "BEGIN:VEVENT",
                     "UID:bad",
                     "DTSTART:not-a-date",
                     "END:VEVENT",
                     "BEGIN:VEVENT",
                     "UID:missing",
                     "SUMMARY:No start",
                     "END:VEVENT",
                     "BEGIN:VEVENT",
                     "DTSTART:20261120T190000Z",
                     "SUMMARY:Good",
                     "END:VEVENT"
                   ])
                 )
      end)

    assert log =~ "unrecognised date/time"
    assert log =~ "missing DTSTART"
  end

  test "rejects data that is not iCalendar" do
    assert {:error, :not_icalendar} = ICS.parse("Hello, this is just an email.")
  end
end
