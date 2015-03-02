defmodule LagerLoggerTest do
  use ExUnit.Case

  alias LagerLogger, as: L

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
