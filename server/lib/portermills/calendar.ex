defmodule Portermills.Calendar do
  import Ecto.Query
  alias Portermills.Repo
  alias Portermills.Calendar.Event

  @doc """
  Events of a family that overlap the half-open range `[from, to)`.

  Events with a yearly `recurrence_rule` (`FREQ=YEARLY`, optionally with
  `INTERVAL=n`) are expanded: each occurrence in the range is returned as the
  same event (same id) with its own `starts_at`/`ends_at`. Other rules aren't
  expanded yet, so those events only appear at their original time.
  """
  def list_events(family_id, %DateTime{} = from, %DateTime{} = to) do
    one_off =
      Repo.all(
        from e in Event,
          where:
            e.family_id == ^family_id and e.starts_at < ^to and e.ends_at >= ^from and
              (is_nil(e.recurrence_rule) or e.recurrence_rule == "")
      )

    recurring =
      Repo.all(
        from e in Event,
          where:
            e.family_id == ^family_id and e.starts_at < ^to and
              not is_nil(e.recurrence_rule) and e.recurrence_rule != ""
      )
      |> Enum.flat_map(&occurrences(&1, from, to))

    Enum.sort_by(one_off ++ recurring, &{DateTime.to_unix(&1.starts_at), &1.title})
  end

  @doc "The occurrences of `event` that overlap `[from, to)`."
  def occurrences(%Event{} = event, %DateTime{} = from, %DateTime{} = to) do
    case yearly_interval(event.recurrence_rule) do
      nil ->
        if overlaps?(event, from, to), do: [event], else: []

      interval ->
        Stream.iterate(0, &(&1 + interval))
        |> Stream.map(&shift_years(event, &1))
        |> Stream.take_while(&(DateTime.compare(&1.starts_at, to) == :lt))
        |> Enum.filter(&overlaps?(&1, from, to))
    end
  end

  @doc "The year step of a yearly rule, or nil if the rule isn't yearly."
  def yearly_interval(nil), do: nil

  def yearly_interval(rule) when is_binary(rule) do
    parts =
      rule
      |> String.replace_prefix("RRULE:", "")
      |> String.split(";", trim: true)
      |> Map.new(fn part ->
        case String.split(part, "=", parts: 2) do
          [k, v] -> {String.upcase(k), String.upcase(v)}
          [k] -> {String.upcase(k), ""}
        end
      end)

    with "YEARLY" <- parts["FREQ"],
         {interval, ""} when interval > 0 <- Integer.parse(parts["INTERVAL"] || "1") do
      interval
    else
      _ -> nil
    end
  end

  defp overlaps?(event, from, to) do
    DateTime.compare(event.starts_at, to) == :lt and DateTime.compare(event.ends_at, from) != :lt
  end

  defp shift_years(event, 0), do: event

  defp shift_years(event, years) do
    %{event | starts_at: add_years(event.starts_at, years), ends_at: add_years(event.ends_at, years)}
  end

  # Same month, day and time of day; 29 February falls back to the 28th.
  defp add_years(%DateTime{} = dt, years) do
    year = dt.year + years
    day = min(dt.day, Calendar.ISO.days_in_month(year, dt.month))
    %{dt | year: year, day: day}
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

  @doc """
  Updates an event. The apps edit whichever occurrence of a yearly event is on
  screen, so for a yearly event the new times are moved back into the series'
  first year: changing the date or time edits the whole series without
  dropping the earlier years.
  """
  def update_event(%Event{} = event, attrs) do
    changeset = Event.changeset(event, attrs)

    changeset =
      with interval when is_integer(interval) <-
             yearly_interval(Ecto.Changeset.get_field(changeset, :recurrence_rule)),
           %DateTime{} = new_start <- Ecto.Changeset.get_change(changeset, :starts_at),
           years when years > 0 <- new_start.year - event.starts_at.year do
        ends_at = Ecto.Changeset.get_field(changeset, :ends_at)

        Ecto.Changeset.change(changeset,
          starts_at: add_years(new_start, -years),
          ends_at: add_years(ends_at, -years)
        )
      else
        _ -> changeset
      end

    Repo.update(changeset)
  end

  def delete_event(%Event{} = event), do: Repo.delete(event)
end
