defmodule Portermills.CalendarRecurrenceTest do
  use Portermills.DataCase, async: true

  alias Portermills.Calendar

  setup do
    family = family_fixture()
    %{family: family, user: user_fixture(family)}
  end

  # A Toronto all-day event on 13 August 2026: 04:00Z to 03:59:59Z next day.
  defp birthday(user, attrs \\ %{}) do
    event_fixture(
      user,
      Enum.into(attrs, %{
        title: "Harry's birthday",
        starts_at: ~U[2026-08-13 04:00:00Z],
        ends_at: ~U[2026-08-14 03:59:59Z],
        all_day: true,
        recurrence_rule: "FREQ=YEARLY"
      })
    )
  end

  defp month(year, month) do
    from = DateTime.new!(Date.new!(year, month, 1), ~T[00:00:00])
    to = DateTime.new!(Date.shift(Date.new!(year, month, 1), month: 1), ~T[00:00:00])
    {from, to}
  end

  defp starts_in(family, {from, to}),
    do: family.id |> Calendar.list_events(from, to) |> Enum.map(& &1.starts_at)

  test "a yearly event appears in its month every year from its first year on",
       %{family: family, user: user} do
    event = birthday(user)

    assert starts_in(family, month(2026, 8)) == [~U[2026-08-13 04:00:00Z]]
    assert starts_in(family, month(2027, 8)) == [~U[2027-08-13 04:00:00Z]]
    assert starts_in(family, month(2040, 8)) == [~U[2040-08-13 04:00:00Z]]
    assert starts_in(family, month(2027, 7)) == []
    assert starts_in(family, month(2025, 8)) == []

    [occurrence] = Calendar.list_events(family.id, elem(month(2030, 8), 0), elem(month(2030, 8), 1))
    assert occurrence.id == event.id
    assert occurrence.ends_at == ~U[2030-08-14 03:59:59Z]
  end

  test "INTERVAL skips years", %{family: family, user: user} do
    birthday(user, recurrence_rule: "RRULE:FREQ=YEARLY;INTERVAL=2")

    assert starts_in(family, month(2027, 8)) == []
    assert starts_in(family, month(2028, 8)) == [~U[2028-08-13 04:00:00Z]]
  end

  test "29 February falls on the 28th in other years", %{family: family, user: user} do
    birthday(user, starts_at: ~U[2028-02-29 05:00:00Z], ends_at: ~U[2028-03-01 04:59:59Z])

    assert starts_in(family, month(2029, 2)) == [~U[2029-02-28 05:00:00Z]]
    assert starts_in(family, month(2032, 2)) == [~U[2032-02-29 05:00:00Z]]
  end

  test "other rules aren't expanded", %{family: family, user: user} do
    birthday(user, recurrence_rule: "FREQ=WEEKLY")

    assert starts_in(family, month(2026, 8)) == [~U[2026-08-13 04:00:00Z]]
    assert starts_in(family, month(2027, 8)) == []
  end

  test "editing a later occurrence edits the series without moving its first year",
       %{user: user} do
    event = birthday(user)

    {:ok, updated} =
      Calendar.update_event(event, %{
        "title" => "Harry's birthday 🎂",
        "starts_at" => "2029-08-12T04:00:00Z",
        "ends_at" => "2029-08-13T03:59:59Z"
      })

    assert updated.title == "Harry's birthday 🎂"
    assert updated.starts_at == ~U[2026-08-12 04:00:00Z]
    assert updated.ends_at == ~U[2026-08-13 03:59:59Z]
    assert updated.recurrence_rule == "FREQ=YEARLY"
  end

  test "one-off events still come back sorted with the recurring ones",
       %{family: family, user: user} do
    birthday(user)
    event_fixture(user, title: "Dentist", starts_at: ~U[2027-08-02 13:00:00Z], ends_at: ~U[2027-08-02 14:00:00Z])

    assert starts_in(family, month(2027, 8)) == [~U[2027-08-02 13:00:00Z], ~U[2027-08-13 04:00:00Z]]
  end
end
