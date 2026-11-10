defmodule Portermills.Calendar do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Calendar.Event

  @doc "Events of a family that overlap the half-open range `[from, to)`."
  def list_events(family_id, %DateTime{} = from, %DateTime{} = to) do
    Repo.all(
      from e in Event,
        where: e.family_id == ^family_id and e.starts_at < ^to and e.ends_at >= ^from,
        order_by: [e.starts_at, e.title]
    )
  end

  def get_event(family_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get_by(Event, id: id, family_id: family_id)
      :error -> nil
    end
  end

  def create_event(family_id, user_id, attrs) do
    %Event{family_id: family_id, created_by_id: user_id}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def delete_event(%Event{} = event), do: Repo.delete(event)
end
