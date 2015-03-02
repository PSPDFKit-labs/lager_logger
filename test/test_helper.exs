ExUnit.start()

defmodule LagerLogger.Case do
  use ExUnit.CaseTemplate

  using _ do
    quote do
      import LagerLogger.Case
    end
  end

  # stop apps without logging to console
  def stop(apps) do
    Logger.flush()
    :ok = Logger.remove_backend(:console)
    _ = for app <- apps, do: Application.stop(app)
    Logger.flush()
    {:ok, _} = Logger.add_backend(:console)
    :ok
  end

  def configure(env) do
    _ = for {key, value} <- env do
      :ok = Application.put_env(:lager, key, value)
    end
    :ok
  end

  # Restart lager with new config, set Logger level, capture all Logger logs,
  # stop lager and then reset Logger level
  def capture_log(lager_env, level, fun) do
    stop([:lager])
    prior_lager_env = :application.get_all_env(:lager)
    prior_level = Logger.level()
    try do
      Logger.configure([level: level])
      configure(lager_env)
      :ok = Application.start(:lager)
      ExUnit.CaptureIO.capture_io(:user, fn ->
        fun.()
        LagerLogger.flush()
      end)
    after
      stop([:lager])
      _ = for {key, _} <- lager_env, do: Application.delete_env(:lager, key)
      configure(prior_lager_env)
      Logger.configure([level: prior_level])
    end
  end
end
