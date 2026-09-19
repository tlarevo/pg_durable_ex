defmodule PgDurable.ConformanceTest do
  @moduledoc """
  Conformance tests for pg_durable v0.2.7 DSL constructs.

  Tests each construct against real PostgreSQL with pg_durable extension.
  Verifies both graph construction and execution via df.start().

  Opt-in:
    PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration
  """

  use ExUnit.Case, async: false

  @moduletag :pg_durable_integration

  alias PgDurable.TestSupport

  @max_wait_seconds 30

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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp query!(conn, sql) do
    Postgrex.query!(conn, sql, [])
  end

  defp start_and_wait(conn, dsl, label \\ nil) do
    # DSL operators (~>, |=>, &, |, ?>, !>, @>) are SQL-level, not inside strings.
    # The DSL itself contains the necessary quotes (e.g., 'SELECT 1' ~> 'SELECT 2').
    # For function calls like df.sleep(1), no quotes are needed.
    start_sql =
      case label do
        nil -> "SELECT df.start(#{dsl})"
        lbl -> "SELECT df.start(#{dsl}, '#{escape_sql(lbl)}')"
      end

    %{rows: [[instance_id]]} = query!(conn, start_sql)
    status = wait_for_completion(conn, instance_id)
    {instance_id, status}
  end

  defp wait_for_completion(conn, instance_id, max_wait \\ @max_wait_seconds) do
    Enum.reduce_while(1..max_wait, :pending, fn _i, _acc ->
      %{rows: [[status]]} = query!(conn, "SELECT df.status('#{instance_id}')")

      if status in ["completed", "failed", "cancelled"] do
        {:halt, status}
      else
        Process.sleep(1000)
        {:cont, :pending}
      end
    end)
  end

  defp get_result(conn, instance_id) do
    %{rows: [[result]]} = query!(conn, "SELECT df.result('#{instance_id}')")
    result
  end

  defp get_status(conn, instance_id) do
    %{rows: [[status]]} = query!(conn, "SELECT df.status('#{instance_id}')")
    status
  end

  defp escape_sql(sql), do: String.replace(sql, "'", "''")

  # ---------------------------------------------------------------------------
  # Graph Operators
  # ---------------------------------------------------------------------------

  describe "Graph Operators" do
    test "Sequence (~>) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT 'SELECT 1' ~> 'SELECT 2'")
      assert graph_json =~ "\"node_type\":\"THEN\""
      assert graph_json =~ "\"query\":\"SELECT 1\""
      assert graph_json =~ "\"query\":\"SELECT 2\""
    end

    test "Sequence (~>) executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "'SELECT 1' ~> 'SELECT 2'")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "Named Result (|=>) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT 'SELECT 1' |=> 'result1'")
      assert graph_json =~ "\"result_name\":\"result1\""
    end

    test "Join (&) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT 'SELECT 1' & 'SELECT 2'")
      assert graph_json =~ "\"node_type\":\"JOIN\""
    end

    test "Join (&) executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "'SELECT 1' & 'SELECT 2'")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "Race (|) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT 'SELECT 1' | df.sleep(1)")
      assert graph_json =~ "\"node_type\":\"RACE\""
    end

    test "Race (|) executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "'SELECT 1' | df.sleep(1)")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "Conditional then/else (?> !>) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT 'SELECT true' ?> 'SELECT 1' !> 'SELECT 2'")

      assert graph_json =~ "\"node_type\":\"IF\""
    end

    test "Conditional then/else (?> !>) executes correctly", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(conn, "'SELECT true' ?> 'SELECT 1' !> 'SELECT 2'")

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "Eternal loop (@>) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT @> ('SELECT 1' ~> df.sleep(1))")

      assert graph_json =~ "\"node_type\":\"LOOP\""
    end
  end

  # ---------------------------------------------------------------------------
  # Graph Functions
  # ---------------------------------------------------------------------------

  describe "Graph Functions" do
    test "SQL node executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "'SELECT 1 AS value'")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "value"
    end

    test "Sleep executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "df.sleep(1)")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "slept"
    end

    test "Wait for schedule constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.wait_for_schedule('* * * * *')")

      assert graph_json =~ "SCHEDULE"
    end

    test "df.join() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.join('SELECT 1', 'SELECT 2')")

      assert graph_json =~ "\"node_type\":\"JOIN\""
    end

    test "df.join() executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "df.join('SELECT 1', 'SELECT 2')")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "df.join3() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.join3('SELECT 1', 'SELECT 2', 'SELECT 3')")

      assert graph_json =~ "\"node_type\":\"JOIN\""
    end

    test "df.join3() executes correctly", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(conn, "df.join3('SELECT 1', 'SELECT 2', 'SELECT 3')")

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "df.race() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.race('SELECT 1', df.sleep(1))")

      assert graph_json =~ "\"node_type\":\"RACE\""
    end

    test "df.race() executes correctly", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "df.race('SELECT 1', df.sleep(1))")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "df.if() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.if('SELECT true', 'SELECT 1', 'SELECT 2')")

      assert graph_json =~ "\"node_type\":\"IF\""
    end

    test "df.if() executes correctly", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(conn, "df.if('SELECT true', 'SELECT 1', 'SELECT 2')")

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end

    test "df.if_rows() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(
          conn,
          "SELECT df.if_rows('test_result', 'SELECT 1', 'SELECT 2')"
        )

      assert graph_json =~ "\"node_type\":\"IF\""
      assert graph_json =~ "result_has_rows"
    end

    test "df.loop() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.loop('SELECT 1', NULL)")

      assert graph_json =~ "\"node_type\":\"LOOP\""
    end

    test "df.break() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT df.break()")
      assert graph_json =~ "BREAK"
    end

    test "df.break(value) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} = query!(conn, "SELECT df.break('done')")
      assert graph_json =~ "BREAK"
    end

    test "df.wait_for_signal() constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.wait_for_signal('test_signal')")

      assert graph_json =~ "SIGNAL"
    end

    test "df.wait_for_signal(timeout) constructs valid graph", %{conn: conn} do
      %{rows: [[graph_json]]} =
        query!(conn, "SELECT df.wait_for_signal('test_signal', 5)")

      assert graph_json =~ "SIGNAL"
    end
  end

  # ---------------------------------------------------------------------------
  # Result Substitution
  # ---------------------------------------------------------------------------

  describe "Result Substitution" do
    test "Named result reference works", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(conn, "'SELECT 42 AS val' |=> 'x' ~> 'SELECT $x'")

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "42"
    end

    test "Column access works", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(conn, "'SELECT 42 AS val' |=> 'x' ~> 'SELECT $x.val'")

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "42"
    end

    test "Row-set expansion works", %{conn: conn} do
      {instance_id, status} =
        start_and_wait(
          conn,
          "'SELECT 1 AS a UNION SELECT 2 AS a' |=> 'batch' ~> 'SELECT * FROM $batch.*'"
        )

      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "\"a\": 1"
      assert result =~ "\"a\": 2"
    end
  end

  # ---------------------------------------------------------------------------
  # Control-Plane Functions
  # ---------------------------------------------------------------------------

  describe "Control-Plane Functions" do
    test "df.start returns instance ID", %{conn: conn} do
      %{rows: [[instance_id]]} = query!(conn, "SELECT df.start('SELECT 1')")
      assert is_binary(instance_id) and byte_size(instance_id) == 8
    end

    test "df.start with label stores label", %{conn: conn} do
      %{rows: [[instance_id]]} =
        query!(conn, "SELECT df.start('SELECT 1', 'test-label')")

      assert is_binary(instance_id) and byte_size(instance_id) == 8
    end

    test "df.status returns valid status", %{conn: conn} do
      %{rows: [[instance_id]]} = query!(conn, "SELECT df.start('SELECT 1')")
      Process.sleep(1000)
      status = get_status(conn, instance_id)
      assert status in ["completed", "running", "pending"]
    end

    test "df.result returns result", %{conn: conn} do
      {instance_id, status} = start_and_wait(conn, "'SELECT 42 AS value'")
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "42"
    end

    test "df.cancel cancels instance", %{conn: conn} do
      %{rows: [[instance_id]]} =
        query!(conn, "SELECT df.start('SELECT pg_sleep(30)')")

      Process.sleep(500)
      query!(conn, "SELECT df.cancel('#{instance_id}', 'Test cancel')")
      Process.sleep(1000)
      status = get_status(conn, instance_id)
      assert status in ["cancelled", "failed"]
    end

    test "df.explain returns output", %{conn: conn} do
      %{rows: [[explain_output]]} =
        query!(conn, "SELECT df.explain('SELECT 1')")

      assert explain_output != nil and explain_output != ""
    end

    test "df.list_instances returns rows", %{conn: conn} do
      %{rows: _rows} = query!(conn, "SELECT * FROM df.list_instances() LIMIT 1")
    end

    test "df.signal sends signal to waiting instance", %{conn: conn} do
      %{rows: [[instance_id]]} =
        query!(conn, "SELECT df.start('df.wait_for_signal(''test'', 2)')")

      Process.sleep(500)

      %{rows: [[signal_result]]} =
        query!(
          conn,
          "SELECT df.signal('#{instance_id}', 'test', '{\"key\": \"value\"}')"
        )

      assert signal_result != nil
    end
  end

  # ---------------------------------------------------------------------------
  # Builder + Renderer Integration
  # ---------------------------------------------------------------------------

  describe "Builder + Renderer Integration" do
    alias PgDurable.Workflow.Builder
    alias PgDurable.Renderer

    test "simple conditional workflow executes correctly", %{conn: conn} do
      workflow =
        Builder.new(
          name: "conditional_test",
          root:
            Builder.if_(
              "SELECT true",
              Builder.sql("SELECT 1 AS result"),
              Builder.sql("SELECT 2 AS result")
            )
        )

      assert {:ok, sql} = Renderer.to_start_sql(workflow)
      assert sql =~ "SELECT df.start("
      assert sql =~ "df.if("

      {instance_id, status} = start_and_wait_from_sql(conn, sql)
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "1"
    end

    test "nested sequence with named results", %{conn: conn} do
      workflow =
        Builder.new(
          name: "nested_named_test",
          root:
            Builder.then(
              Builder.named(Builder.sql("SELECT 42 AS val"), "x"),
              Builder.named(
                Builder.sql("SELECT $x.val * 2 AS doubled"),
                "y"
              )
            )
        )

      assert {:ok, sql} = Renderer.to_start_sql(workflow)
      assert sql =~ "|=>"

      {instance_id, status} = start_and_wait_from_sql(conn, sql)
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "84"
    end

    test "join with named results", %{conn: conn} do
      workflow =
        Builder.new(
          name: "join_named_test",
          root:
            Builder.join(
              Builder.named(Builder.sql("SELECT 10 AS a"), "left_result"),
              Builder.named(Builder.sql("SELECT 20 AS b"), "right_result")
            )
        )

      assert {:ok, sql} = Renderer.to_start_sql(workflow)
      assert sql =~ "&"
      assert sql =~ "|=>"

      {instance_id, status} = start_and_wait_from_sql(conn, sql)
      assert status == "completed"
      result = get_result(conn, instance_id)
      assert result =~ "row_count"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers for Builder+Renderer integration tests
  # ---------------------------------------------------------------------------

  defp start_and_wait_from_sql(conn, sql) do
    %{rows: [[instance_id]]} = query!(conn, sql)
    status = wait_for_completion(conn, instance_id)
    {instance_id, status}
  end
end
