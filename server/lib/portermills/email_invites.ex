defmodule Portermills.EmailInvites do
  @moduledoc """
  Adds calendar invites that family members email (or forward) to the app's address,
  app@portermills.net, to their family's calendar.

  `Portermills.EmailInvites.Poller` fetches new mail from Fastmail and hands each
  message to `import_email/1`, which:

    1. looks up the family member whose address is in `From:`, and rejects the email
       if there is none;
    2. checks the mail server's DKIM/DMARC verdict so that `From:` can't be spoofed
       (see `Portermills.EmailInvites.SenderVerification`);
    3. parses each attached `.ics` and creates, updates or deletes events on the
       sender's family calendar, broadcasting each change on `family:<id>:calendar`.

  Invites are matched by their iCalendar UID, so a re-sent or updated invite updates
  the existing event (if its SEQUENCE is not older) and a cancellation removes it.
  Exceptions for single occurrences of a recurring event (RECURRENCE-ID) are skipped.
  """

  require Logger

  alias Portermills.{Accounts, Calendar}
  alias Portermills.Accounts.User
  alias Portermills.Calendar.Event
  alias Portermills.EmailInvites.{ICS, SenderVerification}

  @type email :: %{
          required(:from) => String.t() | nil,
          required(:authentication_results) => [String.t()],
          required(:calendars) => [binary()]
        }

  @type outcome ::
          {:created, Event.t()}
          | {:updated, Event.t()}
          | {:deleted, Event.t()}
          | {:skipped, term()}

  @doc """
  Imports the calendar attachments of one email.

  Returns `{:ok, outcomes}` (one per event in the attachments), or
  `{:rejected, reason}` if the email is not from a verified family member. Both are
  final: the email should not be retried.
  """
  @spec import_email(email()) :: {:ok, [outcome()]} | {:rejected, atom()}
  def import_email(%{from: from, authentication_results: auth_results, calendars: calendars}) do
    with {:ok, user} <- find_sender(from),
         :ok <- SenderVerification.verify(from, auth_results, config(:trusted_authserv_suffix)) do
      {:ok, Enum.flat_map(calendars, &import_calendar(&1, user))}
    end
  end

  defp find_sender(nil), do: {:rejected, :no_sender}

  defp find_sender(from) do
    case Accounts.find_user_by_email(from) do
      %User{} = user -> {:ok, user}
      nil -> {:rejected, :sender_not_family_member}
    end
  end

  defp import_calendar(data, user) do
    case ICS.parse(data, default_time_zone: config(:default_time_zone)) do
      {:ok, method, vevents} -> Enum.map(vevents, &apply_vevent(&1, method, user))
      {:error, reason} -> [{:skipped, reason}]
    end
  end

  defp apply_vevent(%ICS.VEvent{recurrence_id: rid}, _method, _user) when not is_nil(rid),
    do: {:skipped, :single_occurrence_change}

  defp apply_vevent(vevent, method, user) do
    cond do
      method == "CANCEL" or vevent.status == "CANCELLED" -> cancel(vevent, user)
      method in [nil, "REQUEST", "PUBLISH"] -> upsert(vevent, user)
      # REPLY, COUNTER, REFRESH etc. are responses about an invite, not invites.
      true -> {:skipped, {:unsupported_method, method}}
    end
  end

  defp upsert(vevent, user) do
    attrs = event_attrs(vevent, user)

    case existing_event(vevent, user) do
      nil ->
        attrs
        |> Map.put(:created_by_id, user.id)
        |> Calendar.create_imported_event()
        |> broadcast_result(:created, "calendar:event_created")

      %Event{ical_sequence: current} when vevent.sequence < current ->
        {:skipped, :outdated_invite}

      %Event{} = event ->
        event
        |> Calendar.update_imported_event(attrs)
        |> broadcast_result(:updated, "calendar:event_updated")
    end
  end

  defp cancel(vevent, user) do
    case existing_event(vevent, user) do
      nil ->
        {:skipped, :cancelled_event_not_found}

      %Event{} = event ->
        event
        |> Calendar.delete_event()
        |> broadcast_result(:deleted, "calendar:event_deleted")
    end
  end

  defp existing_event(%ICS.VEvent{uid: nil}, _user), do: nil

  defp existing_event(%ICS.VEvent{uid: uid}, user),
    do: Calendar.get_event_by_ical_uid(user.family_id, uid)

  defp event_attrs(vevent, user) do
    %{
      title: truncate(vevent.title || "(No title)", 255),
      description: description(vevent),
      starts_at: vevent.starts_at,
      ends_at: vevent.ends_at,
      all_day: vevent.all_day,
      # The column is a varchar(255); a truncated rule would be wrong, so drop it.
      recurrence_rule:
        if(vevent.recurrence_rule && String.length(vevent.recurrence_rule) <= 255,
          do: vevent.recurrence_rule
        ),
      ical_uid: vevent.uid,
      ical_sequence: vevent.sequence,
      family_id: user.family_id
    }
  end

  defp description(%ICS.VEvent{location: location, description: description}) do
    [location && "Location: #{location}", description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp truncate(text, max), do: String.slice(text, 0, max)

  defp broadcast_result({:ok, event}, outcome, message) do
    PortermillsWeb.Endpoint.broadcast("family:#{event.family_id}:calendar", message, %{
      event: event
    })

    {outcome, event}
  end

  defp broadcast_result({:error, changeset}, _outcome, _message),
    do: {:skipped, {:invalid, changeset.errors}}

  defp config(key), do: Application.fetch_env!(:portermills, __MODULE__)[key]
end
