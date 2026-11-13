defmodule Portermills.EmailInvites.MIME do
  @moduledoc """
  Finds calendar data (`text/calendar`, `application/ics` or `*.ics` parts) in a MIME
  message, decoding base64 and quoted-printable parts.

  Walks nested multiparts and attached messages (`message/rfc822`), so it finds an
  invite whether it was sent inline (Outlook), both inline and as `invite.ics` (Gmail),
  or inside an email forwarded as an attachment.
  """

  alias Portermills.EmailInvites.RawEmail

  @calendar_types ["text/calendar", "application/ics"]
  @max_depth 10

  @doc "The decoded contents of every calendar part, without duplicates."
  @spec calendar_parts(RawEmail.t()) :: [binary()]
  def calendar_parts(%RawEmail{} = message) do
    message |> walk(0) |> Enum.uniq()
  end

  defp walk(_part, depth) when depth > @max_depth, do: []

  defp walk(%RawEmail{} = part, depth) do
    {type, params} = content_type(part)

    cond do
      String.starts_with?(type, "multipart/") and is_binary(params["boundary"]) ->
        part.body
        |> split_multipart(params["boundary"])
        |> Enum.flat_map(&walk(RawEmail.parse(&1), depth + 1))

      type == "message/rfc822" ->
        part |> decoded_body() |> RawEmail.parse() |> walk(depth + 1)

      calendar?(type, filename(part, params)) ->
        [decoded_body(part)]

      true ->
        []
    end
  end

  defp calendar?(type, filename) do
    type in @calendar_types or
      (is_binary(filename) and String.ends_with?(String.downcase(filename), ".ics"))
  end

  defp content_type(part) do
    case RawEmail.values(part, "content-type") do
      [value | _] -> parse_header_value(value)
      [] -> {"text/plain", %{}}
    end
  end

  defp filename(part, content_type_params) do
    disposition_params =
      case RawEmail.values(part, "content-disposition") do
        [value | _] -> value |> parse_header_value() |> elem(1)
        [] -> %{}
      end

    disposition_params["filename"] || content_type_params["name"]
  end

  # "multipart/mixed; boundary=\"abc\"; charset=utf-8" -> {"multipart/mixed", %{"boundary" => "abc", ...}}
  defp parse_header_value(value) do
    [type | _] = String.split(value, ";", parts: 2)

    params =
      ~r/;\s*([\w\-\*\.]+)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^;\s]+))/
      |> Regex.scan(value, capture: :all_but_first)
      |> Map.new(fn
        [key, quoted] -> {String.downcase(key), quoted}
        [key, "", bare] -> {String.downcase(key), bare}
      end)

    {type |> String.trim() |> String.downcase(), params}
  end

  # Parts sit between lines "--boundary"; the last one is followed by "--boundary--".
  defp split_multipart(body, boundary) do
    ("\r\n" <> body)
    |> String.split("\r\n--" <> boundary)
    |> Enum.drop(1)
    |> Enum.take_while(&(not String.starts_with?(&1, "--")))
    |> Enum.map(fn segment ->
      # Drop the rest of the delimiter line (transport padding).
      case :binary.split(segment, "\r\n") do
        [_padding, part] -> part
        [_] -> ""
      end
    end)
  end

  defp decoded_body(part) do
    encoding =
      case RawEmail.values(part, "content-transfer-encoding") do
        [value | _] -> value |> String.trim() |> String.downcase()
        [] -> "7bit"
      end

    decode(part.body, encoding)
  end

  defp decode(body, "base64") do
    case body |> String.replace(~r/\s/, "") |> Base.decode64(padding: false) do
      {:ok, decoded} -> decoded
      :error -> body
    end
  end

  defp decode(body, "quoted-printable") do
    body
    |> String.replace(~r/=\r\n/, "")
    |> then(
      &Regex.replace(~r/=([0-9A-Fa-f]{2})/, &1, fn _, hex -> <<String.to_integer(hex, 16)>> end)
    )
  end

  defp decode(body, _identity), do: body
end
