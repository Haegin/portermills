defmodule Portermills.EmailInvites.SenderVerification do
  @moduledoc """
  Decides whether an email really came from the address in its `From:` header.

  `From:` is trivially forged, so we rely on the `Authentication-Results` header that
  the receiving mail server (Fastmail) adds after checking DKIM/DMARC. Only the topmost
  header is considered, because that is the one Fastmail prepended on delivery; any
  further headers came with the message and may be forged. As a further check, the
  topmost header must name a server whose hostname ends with the configured
  `trusted_authserv_suffix` (Fastmail's MX hosts are `*.messagingengine.com`).

  The sender is accepted when either:

    * `dmarc=pass` for the From domain, or
    * `dkim=pass` with a signing domain (`header.d`) aligned with the From domain
      (equal to it, or a parent domain of it).
  """

  @spec verify(String.t(), [String.t()], String.t()) :: :ok | {:rejected, atom()}
  def verify(from_address, authentication_results, trusted_authserv_suffix) do
    with {:ok, from_domain} <- domain_of(from_address),
         [header | _] <- authentication_results,
         {:ok, results} <- parse(header, trusted_authserv_suffix) do
      if Enum.any?(results, &passes?(&1, from_domain)),
        do: :ok,
        else: {:rejected, :sender_not_authenticated}
    else
      [] -> {:rejected, :no_authentication_results}
      {:rejected, _} = rejected -> rejected
    end
  end

  defp domain_of(address) do
    case address |> String.trim() |> String.downcase() |> String.split("@") do
      [local, domain] when local != "" and domain != "" -> {:ok, domain}
      _ -> {:rejected, :invalid_from_address}
    end
  end

  # "mx4.messagingengine.com; dkim=pass (comment) header.d=example.com; dmarc=pass ..."
  defp parse(header, trusted_suffix) do
    [authserv | results] = header |> String.replace(~r/\s+/, " ") |> String.split(";")
    authserv_id = authserv |> String.trim() |> String.split(" ") |> hd() |> String.downcase()

    if trusted_authserv?(authserv_id, trusted_suffix) do
      {:ok, Enum.map(results, &parse_result/1)}
    else
      {:rejected, :untrusted_authentication_results}
    end
  end

  defp trusted_authserv?(id, suffix) do
    suffix = String.downcase(suffix)
    id == suffix or String.ends_with?(id, "." <> suffix)
  end

  defp parse_result(result) do
    # Drop (comments) so their contents can't be mistaken for properties.
    result = Regex.replace(~r/\([^)]*\)/, result, " ")

    {method, outcome} =
      case Regex.run(~r/^\s*([\w-]+)\s*=\s*([\w-]+)/, result) do
        [_, method, outcome] -> {String.downcase(method), String.downcase(outcome)}
        nil -> {nil, nil}
      end

    props =
      ~r/([\w-]+\.[\w-]+)\s*=\s*"?([^\s";]+)"?/
      |> Regex.scan(result)
      |> Map.new(fn [_, key, value] -> {String.downcase(key), String.downcase(value)} end)

    %{method: method, outcome: outcome, props: props}
  end

  defp passes?(%{method: "dmarc", outcome: "pass", props: props}, from_domain),
    do: props["header.from"] == from_domain

  defp passes?(%{method: "dkim", outcome: "pass", props: props}, from_domain),
    do: aligned?(props["header.d"], from_domain)

  defp passes?(_result, _from_domain), do: false

  defp aligned?(nil, _from_domain), do: false
  defp aligned?(domain, domain), do: true
  defp aligned?(signing, from_domain), do: String.ends_with?(from_domain, "." <> signing)
end
