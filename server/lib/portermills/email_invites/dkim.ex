defmodule Portermills.EmailInvites.DKIM do
  @moduledoc """
  Verifies that a message was really sent by the domain in its `From:` address, using
  DKIM signatures (RFC 6376).

  `From:` is trivially forged, but a valid DKIM signature can only be made with the
  private key of the signing domain (`d=`), whose public key is published in DNS. We
  accept a message when at least one signature:

    * uses `rsa-sha256` (`rsa-sha1` is no longer considered secure, RFC 8301),
    * covers the `From` header and the whole body (signatures with `l=` are refused,
      since unsigned content could be appended),
    * is from a domain aligned with the From address (the same domain, or a parent
      of it), and has not expired (`x=`),
    * has a body hash and signature that check out against the key in DNS.

  DKIM survives forwarding (unlike SPF), so this works for mail that reaches us via
  Fastmail → Postmark. Every major mail provider signs outgoing mail.
  """

  alias Portermills.EmailInvites.RawEmail

  @doc """
  Returns `:ok` if a valid, aligned signature is found, otherwise `{:error, reasons}`
  with one `{signing_domain, reason}` per signature (or `[:no_signature]`).
  """
  @spec verify(RawEmail.t(), String.t()) :: :ok | {:error, [term()]}
  def verify(%RawEmail{} = message, from_domain) do
    from_domain = String.downcase(from_domain)

    signatures = for {"dkim-signature", raw} <- message.headers, do: raw

    results = Enum.map(signatures, &verify_signature(&1, message, from_domain))

    cond do
      signatures == [] -> {:error, [:no_signature]}
      :ok in results -> :ok
      true -> {:error, for({:error, reason} <- results, do: reason)}
    end
  end

  defp verify_signature(raw_signature, message, from_domain) do
    case parse_tags(RawEmail.value(raw_signature)) do
      {:ok, tags} ->
        case check_signature(tags, raw_signature, message, from_domain) do
          :ok -> :ok
          {:error, reason} -> {:error, {tags["d"], reason}}
        end

      {:error, reason} ->
        {:error, {nil, reason}}
    end
  end

  defp check_signature(tags, raw_signature, message, from_domain) do
    with :ok <- check_tags(tags, from_domain),
         {:ok, header_canon, body_canon} <- canonicalization(tags),
         :ok <- check_body_hash(message.body, body_canon, tags["bh"]),
         {:ok, key} <- public_key(tags["s"], tags["d"]) do
      data =
        signed_headers(message.headers, tags["h"], header_canon) <>
          signature_header(raw_signature, header_canon)

      if :public_key.verify(data, :sha256, tags["b"], key),
        do: :ok,
        else: {:error, :bad_signature}
    end
  end

  # -- Tags ---------------------------------------------------------------------

  defp parse_tags(value) do
    tags =
      value
      |> String.split(";")
      |> Enum.flat_map(fn pair ->
        case String.split(pair, "=", parts: 2) do
          [key, val] -> [{String.trim(key), val |> String.replace(~r/\s/, "")}]
          _ -> []
        end
      end)
      |> Map.new()

    with %{"b" => b64, "bh" => bh64} <- tags,
         {:ok, b} <- Base.decode64(b64),
         {:ok, bh} <- Base.decode64(bh64) do
      {:ok,
       tags
       |> Map.put("b", b)
       |> Map.put("bh", bh)
       |> Map.update("d", nil, &String.downcase/1)
       |> Map.update("h", [], fn h -> h |> String.downcase() |> String.split(":", trim: true) end)}
    else
      _ -> {:error, :malformed_signature}
    end
  end

  defp check_tags(tags, from_domain) do
    cond do
      tags["v"] != "1" -> {:error, :unsupported_version}
      tags["a"] != "rsa-sha256" -> {:error, {:unsupported_algorithm, tags["a"]}}
      is_nil(tags["d"]) or is_nil(tags["s"]) -> {:error, :malformed_signature}
      "from" not in tags["h"] -> {:error, :from_not_signed}
      Map.has_key?(tags, "l") -> {:error, :partial_body_signature}
      not aligned?(tags["d"], from_domain) -> {:error, :not_aligned_with_from}
      expired?(tags["x"]) -> {:error, :expired}
      true -> :ok
    end
  end

  defp aligned?(domain, domain), do: true
  defp aligned?(signing, from_domain), do: String.ends_with?(from_domain, "." <> signing)

  defp expired?(nil), do: false

  defp expired?(x) do
    case Integer.parse(x) do
      {expires, ""} -> expires < System.os_time(:second)
      _ -> true
    end
  end

  defp canonicalization(tags) do
    case String.split(Map.get(tags, "c", "simple/simple"), "/") do
      [header] when header in ["simple", "relaxed"] ->
        {:ok, header, "simple"}

      [header, body] when header in ["simple", "relaxed"] and body in ["simple", "relaxed"] ->
        {:ok, header, body}

      _ ->
        {:error, :unsupported_canonicalization}
    end
  end

  # -- Body -----------------------------------------------------------------------

  defp check_body_hash(body, canon, expected) do
    if :crypto.hash(:sha256, canonical_body(body, canon)) == expected,
      do: :ok,
      else: {:error, :body_hash_mismatch}
  end

  @doc false
  def canonical_body(body, "simple") do
    case strip_trailing_empty_lines(body) do
      "" -> "\r\n"
      stripped -> stripped <> "\r\n"
    end
  end

  def canonical_body(body, "relaxed") do
    body
    |> String.split("\r\n")
    |> Enum.map(fn line ->
      line |> String.replace(~r/[ \t]+/, " ") |> String.trim_trailing(" ")
    end)
    |> Enum.join("\r\n")
    |> strip_trailing_empty_lines()
    |> case do
      "" -> ""
      stripped -> stripped <> "\r\n"
    end
  end

  defp strip_trailing_empty_lines(body), do: String.replace(body, ~r/(\r\n)+\z/, "")

  # -- Headers ----------------------------------------------------------------------

  # Each name in h= takes the next unused instance of that header from the bottom up;
  # names with no instance left contribute nothing (RFC 6376 §5.4.2).
  defp signed_headers(headers, names, canon) do
    {data, _used} =
      Enum.reduce(names, {"", %{}}, fn name, {acc, used} ->
        instances = for {^name, raw} <- headers, do: raw
        skip = Map.get(used, name, 0)

        case instances |> Enum.reverse() |> Enum.at(skip) do
          nil -> {acc, used}
          raw -> {acc <> canonical_header(raw, canon) <> "\r\n", Map.put(used, name, skip + 1)}
        end
      end)

    data
  end

  # The signature's own header, with the b= value emptied and no trailing CRLF.
  defp signature_header(raw, canon) do
    [name, value] = :binary.split(raw, ":")
    value = Regex.replace(~r/((?:^|;)\s*b\s*=)[^;]*/, value, "\\1")
    canonical_header(name <> ":" <> value, canon)
  end

  defp canonical_header(raw, "simple"), do: raw

  defp canonical_header(raw, "relaxed") do
    [name, value] = :binary.split(raw, ":")

    value =
      value
      |> String.replace("\r\n", "")
      |> String.replace(~r/[ \t]+/, " ")
      |> String.trim()

    String.downcase(String.trim(name)) <> ":" <> value
  end

  # -- Keys -----------------------------------------------------------------------

  defp public_key(selector, domain) do
    {module, function} =
      Application.get_env(:portermills, __MODULE__)[:txt_lookup] || {__MODULE__, :dns_txt}

    with {:ok, records} <- apply(module, function, ["#{selector}._domainkey.#{domain}"]) do
      records
      |> Enum.find_value({:error, :no_usable_key}, &decode_key_record/1)
    end
  end

  defp decode_key_record(record) do
    tags =
      record
      |> String.split(";")
      |> Map.new(fn pair ->
        case String.split(pair, "=", parts: 2) do
          [key, val] -> {String.trim(key), String.replace(val, ~r/\s/, "")}
          [key] -> {String.trim(key), ""}
        end
      end)

    with "rsa" <- Map.get(tags, "k", "rsa"),
         p when p not in [nil, ""] <- tags["p"],
         {:ok, der} <- Base.decode64(p),
         {:ok, key} <- decode_der(der) do
      {:ok, key}
    else
      _ -> nil
    end
  end

  defp decode_der(der) do
    {:ok, :public_key.pem_entry_decode({:SubjectPublicKeyInfo, der, :not_encrypted})}
  rescue
    _ ->
      try do
        {:ok, :public_key.der_decode(:RSAPublicKey, der)}
      rescue
        _ -> :error
      end
  end

  @doc "Looks up the TXT records for a name in DNS."
  def dns_txt(name) do
    case :inet_res.lookup(String.to_charlist(name), :in, :txt, [], 5_000) do
      [] ->
        {:error, :no_key_in_dns}

      records ->
        {:ok,
         Enum.map(records, fn chunks -> chunks |> Enum.map(&List.to_string/1) |> Enum.join() end)}
    end
  end
end
