defmodule NskCliTest do
  use ExUnit.Case
  doctest NskCli

  test "greets the world" do
    assert NskCli.hello() == :world
  end
end
