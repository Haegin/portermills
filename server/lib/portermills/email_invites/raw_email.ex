defmodule Portermills.EmailInvites.RawEmail do
  @moduledoc """
  Splits a raw RFC 5322 message (or MIME part) into its header fields and body.

  Header fields are kept exactly as received (including folding), because DKIM's
  "simple" canonicalization signs the original bytes. Bare LF line endings are
  normalised to CRLF first, as they would be on the wire.
  """

  defstruct headers: [], body: ""

  @type header :: {name :: String.t(), raw :: String.t()}
  @type t :: %__MODULE__{headers: [header()], body: binary()}

  @doc "Parses a message. Header names are lower-cased; `raw` is the whole field without its final CRLF."
  @spec parse(binary()) :: t()
  def parse(raw) when is_binary(raw) do
    raw = String.replace(raw, ~r/\r?\n/, "\r\n")

    {header_block, body} =
      cond do
        String.starts_with?(raw, "\r\n") -> {"", binary_part(raw, 2, byte_size(raw) - 2)}
        true -> split_once(raw, "\r\n\r\n")
      end

    %__MODULE__{headers: parse_headers(header_block), body: body}
  end

  @doc "The unfolded, trimmed values of every header field with this name, top to bottom."
  @spec values(t(), String.t()) :: [String.t()]
  def values(%__MODULE__{headers: headers}, name) do
    name = String.downcase(name)
    for {^name, raw} <- headers, do: value(raw)
  end

  @doc "The value of a raw header field: everything after the first colon, unfolded and trimmed."
  @spec value(String.t()) :: String.t()
  def value(raw) do
    {_name, value} = split_once(raw, ":")
    value |> String.replace("\r\n", "") |> String.trim()
  end

  @doc """
  The sender's address from the message's single `From:` field, lower-cased.

  Messages with no From, several From fields or several addresses in one field are
  refused: which of them would be "the sender" is ambiguous, which is exactly what a
  forger would exploit.
  """
  @spec from_address(t()) :: {:ok, String.t()} | {:error, atom()}
  def from_address(message) do
    case values(message, "from") do
      [value] -> parse_address(value)
      [] -> {:error, :no_from}
      _ -> {:error, :multiple_from_headers}
    end
  end

  @address ~r/[^\s<>@",;]+@[^\s<>@",;]+/

  defp parse_address(value) do
    angle = Regex.scan(~r/<([^<>]*)>/, value, capture: :all_but_first)

    candidates =
      case angle do
        [] -> Regex.scan(@address, value) |> List.flatten()
        [[inside]] -> Regex.scan(@address, inside) |> List.flatten()
        _ -> [:ambiguous, :ambiguous]
      end

    case candidates do
      [address] -> {:ok, String.downcase(address)}
      [] -> {:error, :invalid_from}
      _ -> {:error, :multiple_from_addresses}
    end
  end

  defp parse_headers(""), do: []

  defp parse_headers(block) do
    block
    |> String.split("\r\n")
    |> Enum.reduce([], fn
      <<c, _::binary>> = line, [{name, raw} | rest] when c in [?\s, ?\t] ->
        [{name, raw <> "\r\n" <> line} | rest]

      line, acc ->
        case :binary.split(line, ":") do
          [name, _] when name != "" -> [{name |> String.trim() |> String.downcase(), line} | acc]
          _ -> acc
        end
    end)
    |> Enum.reverse()
  end

  defp split_once(binary, pattern) do
    case :binary.split(binary, pattern) do
      [head, tail] -> {head, tail}
      [head] -> {head, ""}
    end
  end
end
