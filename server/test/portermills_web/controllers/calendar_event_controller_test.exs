defmodule PortermillsWeb.CalendarEventControllerTest do
  use PortermillsWeb.ConnCase, async: true

  setup :two_families

  @valid %{title: "Parents' evening", starts_at: "2026-11-12T18:00:00Z", ends_at: "2026-11-12T19:00:00Z"}

  test "create, read, update and delete an event", %{conn: conn, user: user} do
    conn = authed(conn, user)

    created = conn |> post("/api/calendar/events", @valid) |> json_response(201)
    assert %{"title" => "Parents' evening", "starts_at" => "2026-11-12T18:00:00Z", "all_day" => false} = created
    assert created["created_by_id"] == user.id
    id = created["id"]

    assert conn |> get("/api/calendar/events/#{id}") |> json_response(200) == created

    updated = conn |> patch("/api/calendar/events/#{id}", %{title: "Moved", all_day: true}) |> json_response(200)
    assert %{"title" => "Moved", "all_day" => true} = updated

    assert conn |> delete("/api/calendar/events/#{id}") |> response(204)
    assert conn |> get("/api/calendar/events/#{id}") |> json_response(404)
  end

  test "index filters by from/to and by year/month", %{conn: conn, user: user} do
    conn = authed(conn, user)
    event_fixture(user, %{title: "Nov"})
    event_fixture(user, %{title: "Dec", starts_at: ~U[2026-12-24 09:00:00Z], ends_at: ~U[2026-12-24 10:00:00Z]})

    titles = fn query -> conn |> get("/api/calendar/events", query) |> json_response(200) |> Enum.map(& &1["title"]) end

    assert titles.(%{year: "2026", month: "11"}) == ["Nov"]
    assert titles.(%{year: "2026", month: "12"}) == ["Dec"]
    assert titles.(%{from: "2026-11-01T00:00:00Z", to: "2027-01-01T00:00:00Z"}) == ["Nov", "Dec"]
    # An offset from a client in another timezone is accepted.
    assert titles.(%{from: "2026-12-24T00:00:00+01:00", to: "2026-12-25T00:00:00+01:00"}) == ["Dec"]
  end

  test "bad ranges and invalid events are rejected", %{conn: conn, user: user} do
    conn = authed(conn, user)
    assert conn |> get("/api/calendar/events", %{from: "yesterday", to: "tomorrow"}) |> json_response(400)
    assert conn |> get("/api/calendar/events", %{year: "2026", month: "13"}) |> json_response(400)

    assert %{"errors" => %{"title" => ["can't be blank"]}} =
             conn |> post("/api/calendar/events", Map.delete(@valid, :title)) |> json_response(422)
  end

  test "writes are broadcast to the family's calendar topic", %{conn: conn, user: user} do
    PortermillsWeb.Endpoint.subscribe("family:#{user.family_id}:calendar")
    conn = authed(conn, user)

    %{"id" => id} = conn |> post("/api/calendar/events", @valid) |> json_response(201)
    assert_receive %Phoenix.Socket.Broadcast{event: "calendar:event_created", payload: %{event: %{id: ^id}}}

    patch(conn, "/api/calendar/events/#{id}", %{title: "Moved"})
    assert_receive %Phoenix.Socket.Broadcast{event: "calendar:event_updated", payload: %{event: %{title: "Moved"}}}

    delete(conn, "/api/calendar/events/#{id}")
    assert_receive %Phoenix.Socket.Broadcast{event: "calendar:event_deleted", payload: %{id: ^id}}
  end

  test "another family can't read, change or delete the event", %{conn: conn, user: user, stranger: stranger} do
    event = event_fixture(user)
    conn = authed(conn, stranger)

    assert conn |> get("/api/calendar/events", %{year: "2026", month: "11"}) |> json_response(200) == []
    assert conn |> get("/api/calendar/events/#{event.id}") |> json_response(404)
    assert conn |> patch("/api/calendar/events/#{event.id}", %{title: "Hacked"}) |> json_response(404)
    assert conn |> delete("/api/calendar/events/#{event.id}") |> json_response(404)

    assert Portermills.Calendar.get_event(user.family_id, event.id).title == "Dentist"
  end

  test "an event can't be created in another family", %{conn: conn, user: user, stranger: stranger} do
    body = conn |> authed(stranger) |> post("/api/calendar/events", Map.put(@valid, :family_id, user.family_id)) |> json_response(201)
    assert body["family_id"] == stranger.family_id
  end
end
