defmodule Portermills.Calendar do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Calendar.Event

  def list_events_for_month(family_id, year, month) do
    start = Date.new!(year, month, 1) |> DateTime.new!(Time.new!(0, 0, 0))
    finish = start |> DateTime.add(Date.days_in_month(start) * 86_400, :second)

    Repo.all(
      from e in Event,
        where: e.family_id == ^family_id and e.starts_at >= ^start and e.starts_at < ^finish,
        order_by: e.starts_at
    )
  end

  def get_event!(id), do: Repo.get!(Event, id)

  def create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def delete_event(%Event{} = event), do: Repo.delete(event)

  @doc "Finds the event imported from the invite with the given iCalendar UID."
  def get_event_by_ical_uid(family_id, uid) do
    Repo.get_by(Event, family_id: family_id, ical_uid: uid)
  end

  def create_imported_event(attrs) do
    %Event{}
    |> Event.import_changeset(attrs)
    |> Repo.insert()
  end

  def update_imported_event(%Event{} = event, attrs) do
    event
    |> Event.import_changeset(attrs)
    |> Repo.update()
  end
end
