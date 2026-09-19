defmodule PgDurable.IntegrationTest do
  @moduledoc """
  Integration tests that run against a real PostgreSQL instance with pg_durable.

  These tests are opt-in:
    PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration

  Requires Docker or Podman for disposable PostgreSQL instances.
  See docs/integration_test_contract.md for the full isolation contract.
  """

  use ExUnit.Case, async: false

  @moduletag :pg_durable_integration

  alias PgDurable.TestSupport

  setup do
    unless TestSupport.integration_enabled?() do
      IO.puts("\n  Skipping integration tests (PG_DURABLE_INTEGRATION != 1)\n")
      {:skip, "Integration tests not enabled"}
    else
      conn = TestSupport.connect!()
      TestSupport.ensure_pg_durable_ready!(conn)
      %{conn: conn}
    end
  end

  describe "smoke workflow" do
    test "df.start with SELECT 1 returns instance id", %{conn: conn} do
      %{rows: [[instance_id]]} =
        Postgrex.query!(conn, "SELECT df.start('SELECT 1 AS value')", [])

      assert is_binary(instance_id) or is_integer(instance_id)
    end

    test "df.status returns a valid status", %{conn: conn} do
      %{rows: [[instance_id]]} =
        Postgrex.query!(conn, "SELECT df.start('SELECT 1')", [])

      %{rows: [[status]]} =
        Postgrex.query!(conn, "SELECT df.status($1)", [instance_id])

      assert status in ["completed", "running", "pending", "waiting"]
    end

    test "SELECT 1 workflow completes and returns result", %{conn: conn} do
      %{rows: [[instance_id]]} =
        Postgrex.query!(conn, "SELECT df.start('SELECT 1 AS value')", [])

      # Wait for completion
      Enum.reduce_while(1..30, :pending, fn _i, _acc ->
        %{rows: [[status]]} =
          Postgrex.query!(conn, "SELECT df.status($1)", [instance_id])

        if status == "completed" do
          {:halt, :done}
        else
          Process.sleep(500)
          {:cont, :pending}
        end
      end)

      %{rows: [[status]]} =
        Postgrex.query!(conn, "SELECT df.status($1)", [instance_id])

      assert status == "completed"

      %{rows: [[result]]} =
        Postgrex.query!(conn, "SELECT df.result($1)", [instance_id])

      assert result != nil
    end

    test "df.explain returns output", %{conn: conn} do
      %{rows: [[_explain_output]]} =
        Postgrex.query!(conn, "SELECT df.explain('SELECT 1')", [])
    end
  end
end
