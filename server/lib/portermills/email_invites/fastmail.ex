defmodule Portermills.EmailInvites.Fastmail do
  @moduledoc """
  A minimal JMAP (RFC 8620/8621) client for the Fastmail mailbox that receives invites.

  Authenticates with a Fastmail API token (Settings → Privacy & Security → Integrations
  → API tokens) that has read/write Mail access; write access is needed to tag
  processed messages.

  Messages are found by recipient rather than by folder, so this works whether the
  invite address is its own account or an alias on someone's account. Processed
  messages get the keyword `portermills_imported`; the message itself is left
  where it is.
  """

  @using ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"]
  @processed_keyword "portermills_imported"
  @calendar_types ["text/calendar", "application/ics"]
  # Copies of mail the account sent itself, drafts and deleted mail are not invites.
  @ignored_mailbox_roles ["sent", "drafts", "trash"]

  defstruct [:token, :api_url, :download_url, :account_id]

  @type t :: %__MODULE__{}

  @type message :: %{
          id: String.t(),
          from: String.t() | nil,
          subject: String.t() | nil,
          authentication_results: [String.t()],
          calendar_parts: [%{blob_id: String.t(), name: String.t() | nil, type: String.t()}]
        }

  def processed_keyword, do: @processed_keyword

  @doc "Fetches the JMAP session for the token."
  @spec connect(String.t()) :: {:ok, t()} | {:error, term()}
  def connect(token) do
    with {:ok, body} <- get_json(token, config(:session_url)),
         %{"apiUrl" => api_url, "downloadUrl" => download_url} <- body,
         account_id when is_binary(account_id) <-
           get_in(body, ["primaryAccounts", "urn:ietf:params:jmap:mail"]) do
      {:ok,
       %__MODULE__{
         token: token,
         api_url: api_url,
         download_url: download_url,
         account_id: account_id
       }}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_session}
    end
  end

  @doc """
  Lists messages addressed (To/Cc) to `address` that haven't been processed yet,
  oldest first. Only messages received in the last `:within_days` (default 30) are
  considered, so the first run doesn't import a mailbox's entire history.
  """
  @spec fetch_unprocessed(t(), String.t(), keyword()) :: {:ok, [message()]} | {:error, term()}
  def fetch_unprocessed(%__MODULE__{} = client, address, opts \\ []) do
    within_days = Keyword.get(opts, :within_days, 30)
    limit = Keyword.get(opts, :limit, 25)

    received_after =
      DateTime.utc_now()
      |> DateTime.add(-within_days * 86_400, :second)
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    with {:ok, ignored_mailboxes} <- ignored_mailbox_ids(client) do
      filter = %{
        "operator" => "AND",
        "conditions" => [
          %{"operator" => "OR", "conditions" => [%{"to" => address}, %{"cc" => address}]},
          %{"notKeyword" => @processed_keyword},
          %{"after" => received_after},
          %{"inMailboxOtherThan" => ignored_mailboxes}
        ]
      }

      calls = [
        [
          "Email/query",
          %{
            "accountId" => client.account_id,
            "filter" => filter,
            "sort" => [%{"property" => "receivedAt", "isAscending" => true}],
            "limit" => limit
          },
          "q"
        ],
        [
          "Email/get",
          %{
            "accountId" => client.account_id,
            "#ids" => %{"resultOf" => "q", "name" => "Email/query", "path" => "/ids"},
            "properties" => [
              "id",
              "from",
              "subject",
              "bodyStructure",
              "header:Authentication-Results:asText:all"
            ],
            "bodyProperties" => ["partId", "blobId", "type", "name", "subParts"]
          },
          "g"
        ]
      ]

      with {:ok, %{"g" => %{"list" => emails}}} <- call(client, calls) do
        {:ok, Enum.map(emails, &to_message/1)}
      end
    end
  end

  @doc "Downloads an attachment's contents."
  @spec download(t(), map()) :: {:ok, binary()} | {:error, term()}
  def download(%__MODULE__{} = client, %{blob_id: blob_id} = part) do
    url =
      client.download_url
      |> String.replace("{accountId}", encode(client.account_id))
      |> String.replace("{blobId}", encode(blob_id))
      |> String.replace("{name}", encode(part[:name] || "invite.ics"))
      |> String.replace("{type}", encode(part[:type] || "text/calendar"))

    case Req.request(req(client.token), method: :get, url: url, decode_body: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc "Tags messages as processed so they are not fetched again."
  @spec mark_processed(t(), [String.t()]) :: :ok | {:error, term()}
  def mark_processed(_client, []), do: :ok

  def mark_processed(%__MODULE__{} = client, ids) do
    update = Map.new(ids, &{&1, %{"keywords/#{@processed_keyword}" => true}})

    calls = [["Email/set", %{"accountId" => client.account_id, "update" => update}, "s"]]

    case call(client, calls) do
      {:ok, %{"s" => %{"notUpdated" => not_updated}}} when map_size(not_updated) > 0 ->
        {:error, {:not_updated, not_updated}}

      {:ok, _} ->
        :ok

      error ->
        error
    end
  end

  # -- Internals --------------------------------------------------------------

  defp ignored_mailbox_ids(client) do
    calls = [
      ["Mailbox/get", %{"accountId" => client.account_id, "properties" => ["id", "role"]}, "m"]
    ]

    with {:ok, %{"m" => %{"list" => mailboxes}}} <- call(client, calls) do
      {:ok,
       for(%{"id" => id, "role" => role} <- mailboxes, role in @ignored_mailbox_roles, do: id)}
    end
  end

  # Makes a JMAP API request. Returns the method responses keyed by call id, or the
  # first method-level error.
  defp call(client, method_calls) do
    body = %{"using" => @using, "methodCalls" => method_calls}

    case Req.request(req(client.token), method: :post, url: client.api_url, json: body) do
      {:ok, %Req.Response{status: 200, body: %{"methodResponses" => responses}}} ->
        Enum.reduce_while(responses, {:ok, %{}}, fn
          ["error", error, call_id], _acc -> {:halt, {:error, {:jmap, call_id, error}}}
          [_name, args, call_id], {:ok, acc} -> {:cont, {:ok, Map.put(acc, call_id, args)}}
        end)

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp get_json(token, url) do
    case Req.request(req(token), method: :get, url: url) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp req(token) do
    [auth: {:bearer, token}, receive_timeout: 30_000]
    |> Keyword.merge(config(:req_options) || [])
    |> Req.new()
  end

  defp to_message(email) do
    %{
      id: email["id"],
      from: get_in(email, ["from", Access.at(0), "email"]),
      subject: email["subject"],
      authentication_results: email["header:Authentication-Results:asText:all"] || [],
      calendar_parts:
        email["bodyStructure"]
        |> calendar_parts()
        # Gmail sends the same invite inline and as invite.ics: same content, same blob.
        |> Enum.uniq_by(& &1.blob_id)
    }
  end

  defp calendar_parts(nil), do: []

  defp calendar_parts(%{"subParts" => sub_parts}) when is_list(sub_parts),
    do: Enum.flat_map(sub_parts, &calendar_parts/1)

  defp calendar_parts(%{"blobId" => blob_id} = part) when is_binary(blob_id) do
    type = String.downcase(part["type"] || "")
    name = part["name"]

    if type in @calendar_types or (name && String.ends_with?(String.downcase(name), ".ics")) do
      [%{blob_id: blob_id, name: name, type: type}]
    else
      []
    end
  end

  defp calendar_parts(_part), do: []

  defp encode(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp config(key), do: Application.get_env(:portermills, __MODULE__, [])[key]
end
