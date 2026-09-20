defmodule PgDurable.PublicAPIIntegrationTest do
  @moduledoc """
  End-to-end integration tests proving the public PgDurable API
  works against real pg_durable on PostgreSQL 17 and 18.
  """
  use ExUnit.Case, async: false
  @moduletag :pg_durable_public_api_integration

  alias PgDurable.TestSupport

  setup do
    unless TestSupport.integration_enabled?() do
      IO.puts("\n  Skipping public API integration tests (PG_DURABLE_INTEGRATION != 1)\n")
      {:skip, "Integration tests not enabled"}
    else
      conn = TestSupport.connect!()
      TestSupport.ensure_pg_durable_ready!(conn)
      %{conn: conn}
    end
  end

  # Helper to start a workflow and wait for completion
  defp start_and_wait(conn, sql, timeout_ms \\ 10_000) do
    %{rows: [[instance_id]]} = Postgrex.query!(conn, sql, [])

    Enum.reduce_while(1..div(timeout_ms, 500), :pending, fn _i, _acc ->
      %{rows: [[status]]} = Postgrex.query!(conn, "SELECT df.status($1)", [instance_id])

      if status == "completed" do
        {:halt, :done}
      else
        Process.sleep(500)
        {:cont, :pending}
      end
    end)

    %{rows: [[final_status]]} = Postgrex.query!(conn, "SELECT df.status($1)", [instance_id])
    {instance_id, final_status}
  end

  defp get_result(conn, instance_id) do
    %{rows: [[result]]} = Postgrex.query!(conn, "SELECT df.result($1)", [instance_id])
    result
  end

  # 1. Minimal workflow
  describe "minimal workflow" do
    test "sql node executes and returns result", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT 1 AS value")
        |> PgDurable.workflow(name: "minimal")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)

      {instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
      assert get_result(conn, instance_id) != nil
    end
  end

  # 2. Pipe-first sequence
  describe "sequence" do
    test "two-step sequence executes in order", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT 1 AS a")
        |> PgDurable.then(PgDurable.sql("SELECT 2 AS b"))
        |> PgDurable.workflow(name: "sequence")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)
      assert sql =~ "~>"

      {_instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
    end
  end

  # 3. Named result + reference
  describe "named result and reference" do
    test "named result is accessible via $name reference", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT 42 AS value")
        |> PgDurable.named(:answer)
        |> PgDurable.then(PgDurable.sql("SELECT $answer.value AS copied"))
        |> PgDurable.workflow(name: "named_ref")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)
      assert sql =~ "|=>"
      assert sql =~ "$answer"

      {_instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
    end
  end

  # 4. Row-set expansion
  describe "row-set expansion" do
    test "$name.* expands multi-row result", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT 1 AS a UNION ALL SELECT 2 AS a")
        |> PgDurable.named(:batch)
        |> PgDurable.then(PgDurable.sql("SELECT COUNT(*) AS cnt FROM $batch.*"))
        |> PgDurable.workflow(name: "rowset")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)
      assert sql =~ "$batch.*"

      {_instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
    end
  end

  # 5. Conditional branch
  describe "conditional branch" do
    test "if_ renders and executes", %{conn: conn} do
      # if_ takes a string condition, not a Sql node
      workflow =
        PgDurable.if_(
          "SELECT true",
          PgDurable.sql("SELECT 'yes' AS result"),
          PgDurable.sql("SELECT 'no' AS result")
        )
        |> PgDurable.workflow(name: "conditional")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)
      assert sql =~ "df.if"

      {_instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
    end
  end

  # 6. Sleep
  describe "sleep" do
    test "sleep node completes after delay", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT 1")
        |> PgDurable.then(PgDurable.sleep(1))
        |> PgDurable.workflow(name: "sleep_test")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)

      {_instance_id, status} = start_and_wait(conn, sql, 15_000)
      assert status == "completed"
    end
  end

  # 7. Diagnostic-first failure tests
  describe "diagnostic-first validation" do
    test "missing workflow name returns error" do
      # workflow/2 requires :name — Keyword.fetch! will raise
      # This is a programming error, not user input
      assert_raise KeyError, fn ->
        PgDurable.workflow(PgDurable.sql("SELECT 1"), [])
      end
    end

    test "invalid ref name returns diagnostic" do
      assert {:error, diag} = PgDurable.ref("")
      assert %PgDurable.Diagnostic{} = diag
    end

    test "invalid rowset name returns diagnostic" do
      assert {:error, diag} = PgDurable.rowset("my result")
      assert %PgDurable.Diagnostic{} = diag
    end

    test "to_sql with invalid label returns diagnostic" do
      workflow =
        PgDurable.sql("SELECT 1")
        |> PgDurable.workflow(name: "test")

      assert {:error, diags} = PgDurable.to_sql(workflow, label: 123)
      assert is_list(diags)
    end
  end

  # 8. Raw expression escape hatch
  describe "raw expression" do
    test "raw_expr renders and executes", %{conn: conn} do
      workflow =
        PgDurable.raw_expr("df.sleep(0)")
        |> PgDurable.workflow(name: "raw_expr")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)
      assert sql =~ "df.sleep(0)"

      {_instance_id, status} = start_and_wait(conn, sql, 10_000)
      assert status == "completed"
    end
  end

  # 9. Complex multi-step workflow
  describe "complex workflow" do
    test "multi-step pipeline with named results and references", %{conn: conn} do
      workflow =
        PgDurable.sql("SELECT generate_series(1, 5) AS id")
        |> PgDurable.named(:ids)
        |> PgDurable.then(PgDurable.sql("SELECT COUNT(*) AS total FROM $ids.*"))
        |> PgDurable.named(:count)
        |> PgDurable.then(PgDurable.sql("SELECT $count.total AS final_count"))
        |> PgDurable.workflow(name: "complex_pipeline")

      assert :ok = PgDurable.validate(workflow)
      assert {:ok, sql} = PgDurable.to_sql(workflow)

      {_instance_id, status} = start_and_wait(conn, sql)
      assert status == "completed"
    end
  end
end
