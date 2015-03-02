defmodule LagerLoggerTest do
  use LagerLogger.Case

  alias LagerLogger, as: L

  setup_all do
    stop([:lager])
    on_exit(fn() -> Application.start(:lager) end)
    :ok
  end

  test "forward all messages at lager level debug and Logger level debug" do
    lager_env = [handlers: [{LagerLogger, [level: :debug]}]]
    level = :debug

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:debug, self(), 'hello')
    end) =~ "[debug] hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:info, self(), 'hello')
    end) =~ "[info]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:notice, self(), 'hello')
    end) =~ "[info]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:warning, self(), 'hello')
    end) =~ "[warn]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:error, self(), 'hello')
    end) =~ "[error] hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:critical, self(), 'hello')
    end) =~ "[error] hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:alert, self(), 'hello')
    end) =~ "[error] hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:emergency, self(), 'hello')
    end) =~ "[error] hello"
  end

  test "forward all but debug lager messages at lager level :info" do
    lager_env = [handlers: [{LagerLogger, [level: :info]}]]
    level = :debug

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:debug, self(), 'hello')
    end) == ""

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:info, self(), 'hello')
    end) =~ "[info]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:alert, self(), 'hello')
    end) =~ "[error] hello"
  end

  test "forward debug and >info lager messages at lager level !=info" do
    lager_env = [handlers: [{LagerLogger, [level: :"!=info"]}]]
    level = :debug

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:debug, self(), 'hello')
    end) =~ "[debug] hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:info, self(), 'hello')
    end) == ""

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:notice, self(), 'hello')
    end) =~ "[info]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:alert, self(), 'hello')
    end) =~ "[error] hello"
  end

  test "forward >= warning lager messages at Logger level warn" do
    lager_env = [handlers: [{LagerLogger, [level: :debug]}]]
    level = :warn

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:debug, self(), 'hello')
    end) == ""

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:notice, self(), 'hello')
    end) == ""

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:warning, self(), 'hello')
    end) =~ "[warn]  hello"

    assert capture_log(lager_env, level, fn() ->
      :lager.log(:critical, self(), 'hello')
    end) =~ "[error] hello"
  end

  test "normalize_pid with metadata containing a pid" do
    metadata = [a: 1, pid: self(), b: 2]
    assert Keyword.equal?(L.normalize_pid(metadata), metadata)
  end

  test "normalize_pid with normal metadata" do
    metadata = [a: 1, b: 2]
    assert Keyword.equal?(L.normalize_pid(metadata), metadata)
  end

  test "normalize_pid with metadata containing a valid pid as charlist" do
    metadata = [a: 1, pid: :erlang.pid_to_list(self()), b: 2]
    assert Keyword.equal?(L.normalize_pid(metadata), [a: 1, pid: self(), b: 2])
  end

  test "normalize_pid with metadata containing an invalid pid" do
    assert Keyword.equal?(L.normalize_pid([a: 1, pid: 'lol', b: 2]), [a: 1, b: 2])
    assert Keyword.equal?(L.normalize_pid([a: 1, pid: "not even a charlist", b: 2]), [a: 1, b: 2])
  end

  test "timestamp" do
    assert {{_, _, _}, {_, _, _, _}} = L.timestamp(:os.timestamp, true)
  end
end
