defmodule Portermills.EmailInvites.ICS do
  @moduledoc """
  A small iCalendar (RFC 5545) parser covering what meeting invites need.

  It reads the calendar's `METHOD` and, for each top-level `VEVENT`, the UID, sequence,
  status, summary, description, location, start/end (or duration) and recurrence rule.
  Nested components such as `VALARM` are ignored.

  Times are returned as UTC `DateTime`s:

    * `20261120T190000Z` is already UTC.
    * `DTSTART;TZID=Europe/London:20261120T190000` is converted from the named zone.
      Outlook's Windows zone names ("GMT Standard Time") are mapped to IANA zones.
    * Times with no zone ("floating") or an unrecognised zone use `:default_time_zone`.
    * Dates (`VALUE=DATE`) become all-day events starting at midnight UTC, with an
      exclusive end date, as in the iCalendar spec.
  """

  require Logger

  defmodule VEvent do
    @moduledoc "One event read from an iCalendar file."
    defstruct [
      :uid,
      :status,
      :title,
      :description,
      :location,
      :starts_at,
      :ends_at,
      :recurrence_rule,
      :recurrence_id,
      sequence: 0,
      all_day: false
    ]

    @type t :: %__MODULE__{}
  end

  # Outlook/Exchange use Windows zone names in TZID. Common ones, from CLDR's windowsZones.
  @windows_zones %{
    "UTC" => "Etc/UTC",
    "Coordinated Universal Time" => "Etc/UTC",
    "GMT Standard Time" => "Europe/London",
    "Greenwich Standard Time" => "Atlantic/Reykjavik",
    "W. Europe Standard Time" => "Europe/Berlin",
    "Romance Standard Time" => "Europe/Paris",
    "Central Europe Standard Time" => "Europe/Budapest",
    "Central European Standard Time" => "Europe/Warsaw",
    "E. Europe Standard Time" => "Europe/Chisinau",
    "FLE Standard Time" => "Europe/Helsinki",
    "GTB Standard Time" => "Europe/Bucharest",
    "Eastern Standard Time" => "America/New_York",
    "Central Standard Time" => "America/Chicago",
    "Mountain Standard Time" => "America/Denver",
    "US Mountain Standard Time" => "America/Phoenix",
    "Pacific Standard Time" => "America/Los_Angeles",
    "Alaskan Standard Time" => "America/Anchorage",
    "Hawaiian Standard Time" => "Pacific/Honolulu",
    "Atlantic Standard Time" => "America/Halifax",
    "Canada Central Standard Time" => "America/Regina",
    "AUS Eastern Standard Time" => "Australia/Sydney",
    "E. Australia Standard Time" => "Australia/Brisbane",
    "Cen. Australia Standard Time" => "Australia/Adelaide",
    "W. Australia Standard Time" => "Australia/Perth",
    "New Zealand Standard Time" => "Pacific/Auckland",
    "Tokyo Standard Time" => "Asia/Tokyo",
    "China Standard Time" => "Asia/Shanghai",
    "Singapore Standard Time" => "Asia/Singapore",
    "India Standard Time" => "Asia/Kolkata",
    "Arabian Standard Time" => "Asia/Dubai",
    "South Africa Standard Time" => "Africa/Johannesburg"
  }

  @doc """
  Parses an iCalendar document.

  Returns `{:ok, method, events}` where `method` is the upper-cased `METHOD` (or `nil`)
  and `events` are the `VEVENT`s that have a usable start time. Events without one are
  dropped with a warning. Returns `{:error, :not_icalendar}` if there is no `VCALENDAR`.
  """
  @spec parse(binary(), keyword()) :: {:ok, String.t() | nil, [VEvent.t()]} | {:error, atom()}
  def parse(data, opts \\ []) when is_binary(data) do
    default_zone = Keyword.get(opts, :default_time_zone, "Etc/UTC")

    lines =
      data
      |> String.replace_prefix("﻿", "")
      |> unfold()
      |> String.split(~r/\r?\n/, trim: true)

    case walk(lines, [], nil, nil, [], false) do
      {_method, _raw_events, false} ->
        {:error, :not_icalendar}

      {method, raw_events, true} ->
        events =
          Enum.flat_map(raw_events, fn props ->
            case build(props, default_zone) do
              {:ok, event} ->
                [event]

              {:error, reason} ->
                Logger.warning("Skipping invite event #{inspect(props["UID"])}: #{reason}")
                []
            end
          end)

        {:ok, method, events}
    end
  end

  # -- Lines and components ---------------------------------------------------

  # Long lines are folded by a line break followed by a single space or tab.
  defp unfold(data), do: String.replace(data, ~r/\r?\n[ \t]/, "")

  # Walks the content lines keeping a stack of open components. Only properties that
  # sit directly inside a VEVENT are collected (the first occurrence of each wins).
  defp walk([], _stack, _current, method, events, seen_cal),
    do: {method, Enum.reverse(events), seen_cal}

  defp walk([line | rest], stack, current, method, events, seen_cal) do
    case parse_line(line) do
      {"BEGIN", _params, component} ->
        component = component |> String.trim() |> String.upcase()
        current = if component == "VEVENT", do: %{}, else: current

        walk(
          rest,
          [component | stack],
          current,
          method,
          events,
          seen_cal or component == "VCALENDAR"
        )

      {"END", _params, component} ->
        case {component |> String.trim() |> String.upcase(), stack} do
          {"VEVENT", ["VEVENT" | tail]} ->
            walk(rest, tail, nil, method, [current | events], seen_cal)

          {_, [_ | tail]} ->
            walk(rest, tail, current, method, events, seen_cal)

          {_, []} ->
            walk(rest, [], current, method, events, seen_cal)
        end

      {"METHOD", _params, value} when stack == ["VCALENDAR"] ->
        walk(rest, stack, current, String.upcase(String.trim(value)), events, seen_cal)

      {name, params, value} when hd(stack) == "VEVENT" ->
        walk(rest, stack, Map.put_new(current, name, {params, value}), method, events, seen_cal)

      _other ->
        walk(rest, stack, current, method, events, seen_cal)
    end
  end

  # NAME;PARAM=value;PARAM="quoted:value":VALUE
  defp parse_line(line) do
    case find_unquoted(line, ?:, false, 0) do
      nil ->
        :invalid

      idx ->
        head = binary_part(line, 0, idx)
        value = binary_part(line, idx + 1, byte_size(line) - idx - 1)
        [name | params] = split_unquoted(head, ?;)
        {String.upcase(name), Map.new(params, &parse_param/1), value}
    end
  end

  defp parse_param(param) do
    case String.split(param, "=", parts: 2) do
      [key, value] -> {String.upcase(key), value |> String.trim() |> String.trim("\"")}
      [key] -> {String.upcase(key), ""}
    end
  end

  defp find_unquoted(<<>>, _char, _quoted, _idx), do: nil

  defp find_unquoted(<<?", rest::binary>>, char, quoted, idx),
    do: find_unquoted(rest, char, not quoted, idx + 1)

  defp find_unquoted(<<char, _::binary>>, char, false, idx), do: idx

  defp find_unquoted(<<_, rest::binary>>, char, quoted, idx),
    do: find_unquoted(rest, char, quoted, idx + 1)

  defp split_unquoted(binary, char) do
    case find_unquoted(binary, char, false, 0) do
      nil ->
        [binary]

      idx ->
        [
          binary_part(binary, 0, idx)
          | split_unquoted(binary_part(binary, idx + 1, byte_size(binary) - idx - 1), char)
        ]
    end
  end

  # -- Building events --------------------------------------------------------

  defp build(props, default_zone) do
    with {:ok, start_prop} <- Map.fetch(props, "DTSTART") |> or_error("missing DTSTART"),
         {:ok, starts_at, all_day} <- parse_time(start_prop, default_zone),
         {:ok, ends_at} <- end_time(props, starts_at, all_day, default_zone) do
      {:ok,
       %VEvent{
         uid: text(props, "UID"),
         sequence: integer(props, "SEQUENCE"),
         status: props |> text("STATUS") |> upcase(),
         title: text(props, "SUMMARY"),
         description: text(props, "DESCRIPTION"),
         location: text(props, "LOCATION"),
         starts_at: starts_at,
         ends_at: ends_at,
         all_day: all_day,
         recurrence_rule: raw(props, "RRULE"),
         recurrence_id: raw(props, "RECURRENCE-ID")
       }}
    end
  end

  defp end_time(props, starts_at, all_day, default_zone) do
    cond do
      Map.has_key?(props, "DTEND") ->
        with {:ok, ends_at, _all_day} <- parse_time(props["DTEND"], default_zone) do
          {:ok, later_of(starts_at, ends_at)}
        end

      Map.has_key?(props, "DURATION") ->
        with {:ok, seconds} <- parse_duration(raw(props, "DURATION")) do
          {:ok, later_of(starts_at, DateTime.add(starts_at, seconds, :second))}
        end

      all_day ->
        {:ok, DateTime.add(starts_at, 86_400, :second)}

      true ->
        {:ok, starts_at}
    end
  end

  defp later_of(a, b), do: if(DateTime.compare(b, a) == :lt, do: a, else: b)

  defp or_error({:ok, _} = ok, _message), do: ok
  defp or_error(:error, message), do: {:error, message}

  defp raw(props, name) do
    case props do
      %{^name => {_params, value}} -> blank_to_nil(String.trim(value))
      _ -> nil
    end
  end

  defp text(props, name) do
    case raw(props, name) do
      nil -> nil
      value -> value |> unescape() |> String.trim() |> blank_to_nil()
    end
  end

  defp integer(props, name) do
    with value when is_binary(value) <- raw(props, name),
         {int, _} <- Integer.parse(value) do
      int
    else
      _ -> 0
    end
  end

  defp upcase(nil), do: nil
  defp upcase(value), do: String.upcase(value)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp unescape(value) do
    Regex.replace(~r/\\([\\;,nN])/, value, fn
      _, "n" -> "\n"
      _, "N" -> "\n"
      _, char -> char
    end)
  end

  # -- Dates, times and durations ---------------------------------------------

  @date ~r/^(\d{4})(\d{2})(\d{2})$/
  @date_time ~r/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/i

  defp parse_time({params, value}, default_zone) do
    value = String.trim(value)

    cond do
      captures = Regex.run(@date, value, capture: :all_but_first) ->
        [y, m, d] = Enum.map(captures, &String.to_integer/1)

        with {:ok, date} <- Date.new(y, m, d) do
          {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC"), true}
        end

      captures = Regex.run(@date_time, value, capture: :all_but_first) ->
        [y, mo, d, h, mi, s] = captures |> Enum.take(6) |> Enum.map(&String.to_integer/1)
        utc? = List.last(captures) != ""

        with {:ok, naive} <- NaiveDateTime.new(y, mo, d, h, mi, min(s, 59)),
             {:ok, utc} <-
               to_utc(
                 naive,
                 if(utc?, do: "Etc/UTC", else: zone_for(params["TZID"], default_zone))
               ) do
          {:ok, utc, false}
        end

      true ->
        {:error, "unrecognised date/time #{inspect(value)}"}
    end
    |> case do
      {:ok, _, _} = ok -> ok
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, "invalid date/time #{inspect(value)} (#{inspect(reason)})"}
    end
  end

  defp to_utc(naive, zone) do
    case DateTime.from_naive(naive, zone) do
      {:ok, datetime} -> {:ok, DateTime.shift_zone!(datetime, "Etc/UTC")}
      # During the autumn "fall back" hour, pick the first occurrence.
      {:ambiguous, first, _second} -> {:ok, DateTime.shift_zone!(first, "Etc/UTC")}
      # During the spring "skip" hour, use the first valid time after the gap.
      {:gap, _before, just_after} -> {:ok, DateTime.shift_zone!(just_after, "Etc/UTC")}
      {:error, _} = error -> error
    end
  end

  defp zone_for(nil, default_zone), do: default_zone

  defp zone_for(tzid, default_zone) do
    tzid = String.trim(tzid)

    # Old Thunderbird/Lightning TZIDs look like "/mozilla.org/20050126_1/Europe/London".
    path_tail = tzid |> String.split("/", trim: true) |> Enum.take(-2) |> Enum.join("/")

    candidates = [tzid, String.trim_leading(tzid, "/"), path_tail, Map.get(@windows_zones, tzid)]

    case Enum.find(candidates, &known_zone?/1) do
      nil ->
        Logger.warning("Unknown invite timezone #{inspect(tzid)}; using #{default_zone}")
        default_zone

      zone ->
        zone
    end
  end

  defp known_zone?(nil), do: false
  defp known_zone?(""), do: false

  defp known_zone?(zone) do
    match?({:ok, _}, DateTime.now(zone))
  end

  @duration ~r/^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i

  defp parse_duration(nil), do: {:error, "empty DURATION"}

  defp parse_duration(value) do
    case Regex.run(@duration, value) do
      [_ | captures] ->
        [sign | parts] = captures ++ List.duplicate("", 6 - length(captures))

        seconds =
          parts
          |> Enum.map(fn
            "" -> 0
            n -> String.to_integer(n)
          end)
          |> Enum.zip([604_800, 86_400, 3_600, 60, 1])
          |> Enum.map(fn {n, unit} -> n * unit end)
          |> Enum.sum()

        {:ok, if(sign == "-", do: -seconds, else: seconds)}

      nil ->
        {:error, "invalid DURATION #{inspect(value)}"}
    end
  end
end
