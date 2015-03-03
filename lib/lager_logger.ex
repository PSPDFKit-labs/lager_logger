defmodule LagerLogger do
  @moduledoc ~S"""
  A lager backend that forwards all log messages to Elixir's Logger.

  To forward all lager messages to Logger and otherwise disable lager
  include the following in a config.exs file:

      use Mix.Config

      # Stop lager redirecting :error_logger messages
      config :lager, :error_logger_redirect, false

      # Stop lager removing Logger's :error_logger handler
      config :lager, :error_logger_whitelist, [Logger.ErrorHandler]

      # Stop lager writing a crash log
      config :lager, :crash_log, false

      # Use LagerLogger as lager's only handler.
      config :lager, :handlers, [{LagerLogger, []}]
  """
  @behaviour :gen_event

  @doc false
  def init([]) do
    {:ok, nil}
  end


  @doc false
  def handle_event({:log, lager_msg}, state) do
    %{mode: mode, truncate: truncate, level: min_level, utc_log: utc_log?} = Logger.Config.__data__
    level = severity_to_level(:lager_msg.severity(lager_msg))

    if Logger.compare_levels(level, min_level) != :lt do
      metadata = :lager_msg.metadata(lager_msg) |> normalize_pid

      # lager_msg's message is already formatted chardata
      message = Logger.Utils.truncate(:lager_msg.message(lager_msg), truncate)

      # Lager always uses local time and converts it when formatting using :lager_util.maybe_utc
      timestamp = timestamp(:lager_msg.timestamp(lager_msg), utc_log?)

      group_leader = case Keyword.fetch(metadata, :pid) do
        {:ok, pid} when is_pid(pid) -> Process.info(pid, :group_leader)
        _ -> Process.group_leader # if lager didn't give us a pid just pretend it's us
      end

      try do
        notify(mode, {level, group_leader, {Logger, message, timestamp, metadata}})
        :ok
      rescue
        ArgumentError -> {:error, :noproc}
      catch
        :exit, reason -> {:error, reason}
      end
    end

    {:ok, state}
  end

  @doc false
  # Always returns debug (=log everything) since lager will prefilter log messages for us based on
  # what we return here. And since we let Logger perform the level filtering we need to receive and
  # forward all log messages to Logger.
  def handle_call(:get_loglevel, state) do
    {:ok, 128, state}
  end

  # Ignored since we forward all log messages to Logger and use its loglevel
  def handle_call({:set_loglevel, _}, state) do
    {:ok, :ok, state}
  end

  @doc false
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc false
  def terminate(_reason, _state), do: :ok

  @doc false
  def code_change(_old, state, _extra), do: {:ok, state}

  # Stolen from Logger.
  defp notify(:sync, msg),  do: GenEvent.sync_notify(Logger, msg)
  defp notify(:async, msg), do: GenEvent.notify(Logger, msg)

  @doc false
  # Lager's parse transform converts the pid into a charlist. Logger's metadata expects pids as
  # actual pids so we need to revert it.
  # If the pid metadata is not a valid pid we remove it completely.
  def normalize_pid(metadata) do
    case Keyword.fetch(metadata, :pid) do
      {:ok, pid} when is_pid(pid) -> metadata
      {:ok, pid} when is_list(pid) ->
        try do
          # Lager's parse transform uses `pid_to_list` so we revert it
          Keyword.put(metadata, :pid, :erlang.list_to_pid(pid))
        rescue
          ArgumentError -> Keyword.delete(metadata, :pid)
        end
      {:ok, _} -> Keyword.delete(metadata, :pid)
      :error -> metadata
    end
  end

  @doc false
  # Returns a timestamp that includes miliseconds. Stolen from Logger.Utils.
  def timestamp(now, utc_log?) do
    {_, _, micro} = now
    {date, {hours, minutes, seconds}} =
      case utc_log? do
        true  -> :calendar.now_to_universal_time(now)
        false -> :calendar.now_to_local_time(now)
      end
    {date, {hours, minutes, seconds, div(micro, 1000)}}
  end

  # Converts lager's severity to Logger's level
  defp severity_to_level(:debug),     do: :debug
  defp severity_to_level(:info),      do: :info
  defp severity_to_level(:notice),    do: :info
  defp severity_to_level(:warning),   do: :warn
  defp severity_to_level(:error),     do: :error
  defp severity_to_level(:critical),  do: :error
  defp severity_to_level(:alert),     do: :error
  defp severity_to_level(:emergency), do: :error
end
