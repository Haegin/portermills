defmodule Portermills.CalendarTest do
  use Portermills.DataCase, async: true

  alias Portermills.Calendar

  setup do
    family = family_fixture()
    %{family: family, user: user_fixture(family)}
  end

  @november {~U[2026-11-01 00:00:00Z], ~U[2026-12-01 00:00:00Z]}

  test "create_event/3 sets the family and creator", %{family: family, user: user} do
    assert {:ok, event} =
             Calendar.create_event(family.id, user.id, %{
               "title" => "Swimming",
               "starts_at" => "2026-11-10T16:00:00Z",
               "ends_at" => "2026-11-10T17:00:00Z"
             })

    assert event.family_id == family.id
    assert event.created_by_id == user.id
    assert event.starts_at == ~U[2026-11-10 16:00:00Z]
  end

  test "family_id can't be set through attrs", %{family: family, user: user} do
    other = family_fixture()

    {:ok, event} =
      Calendar.create_event(family.id, user.id, %{
        "title" => "x",
        "starts_at" => "2026-11-10T16:00:00Z",
        "ends_at" => "2026-11-10T17:00:00Z",
        "family_id" => other.id
      })

    assert event.family_id == family.id
  end

  test "an event needs a title and can't end before it starts", %{family: family, user: user} do
    assert {:error, changeset} =
             Calendar.create_event(family.id, user.id, %{
               starts_at: ~U[2026-11-10 10:00:00Z],
               ends_at: ~U[2026-11-10 09:00:00Z]
             })

    assert %{title: ["can't be blank"], ends_at: ["must not be before the start"]} = errors_on(changeset)
  end

  test "list_events/3 returns events overlapping the range, in order", %{family: family, user: user} do
    {from, to} = @november
    late = event_fixture(user, %{title: "Late", starts_at: ~U[2026-11-20 09:00:00Z], ends_at: ~U[2026-11-20 10:00:00Z]})
    early = event_fixture(user, %{title: "Early", starts_at: ~U[2026-11-02 09:00:00Z], ends_at: ~U[2026-11-02 10:00:00Z]})
    spanning = event_fixture(user, %{title: "Trip", starts_at: ~U[2026-10-28 09:00:00Z], ends_at: ~U[2026-11-03 10:00:00Z]})
    _october = event_fixture(user, %{starts_at: ~U[2026-10-05 09:00:00Z], ends_at: ~U[2026-10-05 10:00:00Z]})
    _december = event_fixture(user, %{starts_at: ~U[2026-12-01 00:00:00Z], ends_at: ~U[2026-12-01 01:00:00Z]})

    assert Enum.map(Calendar.list_events(family.id, from, to), & &1.id) == [spanning.id, early.id, late.id]
  end

  test "events are invisible to other families", %{user: user} do
    {from, to} = @november
    event = event_fixture(user)
    other_family = family_fixture()

    assert Calendar.list_events(other_family.id, from, to) == []
    assert Calendar.get_event(other_family.id, event.id) == nil
    assert Calendar.get_event(user.family_id, event.id).id == event.id
  end

  test "get_event/2 returns nil for a malformed id", %{family: family} do
    assert Calendar.get_event(family.id, "not-a-uuid") == nil
  end

  test "update_event/2 and delete_event/1", %{family: family, user: user} do
    event = event_fixture(user)
    assert {:ok, updated} = Calendar.update_event(event, %{title: "Orthodontist", all_day: true})
    assert updated.title == "Orthodontist"
    assert updated.all_day

    assert {:ok, _} = Calendar.delete_event(updated)
    assert Calendar.get_event(family.id, event.id) == nil
  end
end
