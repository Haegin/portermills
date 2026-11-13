defmodule Portermills.EmailInvites.Poller do
  @moduledoc """
  Periodically checks Fastmail for new mail to the invite address and imports it.

  Started by `Portermills.Application` only when `FASTMAIL_API_TOKEN` is set (see
  `config/runtime.exs`). Each message ends in one of two ways:

    * done (imported, rejected, or no calendar attachment): tagged as processed in
      Fastmail and never fetched again;
    * transient failure (network error, crash while importing): left untagged and
      retried on the next poll.
  """

  use GenServer

  require Logger

  alias Portermills.EmailInvites
  alias Portermills.EmailInvites.Fastmail

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    state = %{
      token: Keyword.fetch!(opts, :token),
      address: Keyword.fetch!(opts, :address),
      interval_ms: Keyword.get(opts, :interval_ms, 60_000)
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case poll_once(state) do
      {:ok, 0} -> :ok
      {:ok, count} -> Logger.info("Email invites: processed #{count} email(s)")
      {:error, reason} -> Logger.warning("Email invites: poll failed: #{inspect(reason)}")
    end

    Process.send_after(self(), :poll, state.interval_ms)
    {:noreply, state}
  end

  @doc """
  Runs one poll: fetch unprocessed messages, import them, tag the finished ones.
  Returns the number of messages tagged as processed.
  """
  @spec poll_once(%{token: String.t(), address: String.t()}) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def poll_once(%{token: token, address: address}) do
    with {:ok, client} <- Fastmail.connect(token),
         {:ok, messages} <- Fastmail.fetch_unprocessed(client, address) do
      done = for message <- messages, process(client, message) == :done, do: message.id

      with :ok <- Fastmail.mark_processed(client, done), do: {:ok, length(done)}
    end
  rescue
    exception -> {:error, exception}
  end

  defp process(client, message) do
    with {:ok, calendars} <- download_all(client, message.calendar_parts) do
      import_message(message, calendars)
    else
      {:error, reason} ->
        Logger.warning(
          "Email invites: could not download attachments of #{message.id}: #{inspect(reason)}"
        )

        :retry
    end
  rescue
    exception ->
      Logger.error(
        "Email invites: failed to import #{message.id}: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )

      :retry
  end

  defp import_message(%{calendar_parts: []} = message, _calendars) do
    Logger.info(
      "Email invites: no calendar attachment in #{inspect(message.subject)} from #{message.from}"
    )

    :done
  end

  defp import_message(message, calendars) do
    email = %{
      from: message.from,
      authentication_results: message.authentication_results,
      calendars: calendars
    }

    case EmailInvites.import_email(email) do
      {:ok, outcomes} ->
        Logger.info(
          "Email invites: #{inspect(message.subject)} from #{message.from}: " <>
            Enum.map_join(outcomes, ", ", &describe/1)
        )

      {:rejected, reason} ->
        Logger.warning(
          "Email invites: rejected #{inspect(message.subject)} from #{inspect(message.from)}: " <>
            "#{reason} (Authentication-Results: #{inspect(List.first(message.authentication_results))})"
        )
    end

    :done
  end

  defp download_all(client, parts) do
    Enum.reduce_while(parts, {:ok, []}, fn part, {:ok, acc} ->
      case Fastmail.download(client, part) do
        {:ok, data} -> {:cont, {:ok, acc ++ [data]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp describe({outcome, %{title: title}}), do: "#{outcome} #{inspect(title)}"
  defp describe({:skipped, reason}), do: "skipped (#{inspect(reason)})"
end
