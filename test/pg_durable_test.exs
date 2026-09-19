defmodule PgDurableTest do
  use ExUnit.Case, async: true

  describe "version/0" do
    test "returns a version string" do
      version = PgDurable.version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+$/
    end
  end
end
