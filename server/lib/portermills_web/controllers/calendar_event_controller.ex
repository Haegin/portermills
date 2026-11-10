defmodule PortermillsWeb.CalendarEventController do
  use PortermillsWeb, :controller

  alias Portermills.Calendar
  alias Portermills.Calendar.Event

  @doc """
  Events overlapping a range. Pass `from` and `to` as ISO 8601 datetimes, or
  `year` and `month` for a whole (UTC) month. Defaults to the current month.
  """
  def index(conn, params) do
    with {:ok, from, to} <- range(params) do
      events = Calendar.list_events(conn.assigns.current_user.family_id, from, to)
      json(conn, Enum.map(events, &event_json/1))
    end
  end

  def show(conn, %{"id" => id}) do
    with %Event{} = event <- Calendar.get_event(conn.assigns.current_user.family_id, id) do
      json(conn, event_json(event))
    end
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    with {:ok, event} <- Calendar.create_event(user.family_id, user.id, params) do
      Broadcast.calendar(user.family_id, "calendar:event_created", %{event: event_json(event)})
      conn |> put_status(:created) |> json(event_json(event))
    end
  end

  def update(conn, %{"id" => id} = params) do
    family_id = conn.assigns.current_user.family_id

    with %Event{} = event <- Calendar.get_event(family_id, id),
         {:ok, event} <- Calendar.update_event(event, params) do
      Broadcast.calendar(family_id, "calendar:event_updated", %{event: event_json(event)})
      json(conn, event_json(event))
    end
  end

  def delete(conn, %{"id" => id}) do
    family_id = conn.assigns.current_user.family_id

    with %Event{} = event <- Calendar.get_event(family_id, id),
         {:ok, _} <- Calendar.delete_event(event) do
      Broadcast.calendar(family_id, "calendar:event_deleted", %{id: event.id})
      send_resp(conn, :no_content, "")
    end
  end

  defp range(%{"from" => from, "to" => to}) do
    with {:ok, from, _} <- DateTime.from_iso8601(from),
         {:ok, to, _} <- DateTime.from_iso8601(to) do
      {:ok, from, to}
    else
      _ -> {:error, :bad_request}
    end
  end

  defp range(%{"year" => year, "month" => month}) do
    with {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {:ok, first} <- Date.new(year, month, 1) do
      {:ok, month_start(first), month_start(Date.shift(first, month: 1))}
    else
      _ -> {:error, :bad_request}
    end
  end

  defp range(_params) do
    first = Date.utc_today() |> Date.beginning_of_month()
    {:ok, month_start(first), month_start(Date.shift(first, month: 1))}
  end

  defp month_start(date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  def event_json(%Event{} = e) do
    %{
      id: e.id,
      title: e.title,
      description: e.description,
      starts_at: e.starts_at,
      ends_at: e.ends_at,
      all_day: e.all_day,
      recurrence_rule: e.recurrence_rule,
      created_by_id: e.created_by_id,
      family_id: e.family_id
    }
  end
end
