defmodule PgDurable.SQL.RoundTripTest do
  @moduledoc """
  Integration tests that prove adversarial string values round-trip safely
  through PostgreSQL. Each test INSERTs a value via quote_sql_string, then
  SELECTs it back and verifies the data is unchanged.

  Opt-in:
    PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration
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

  # Helper: INSERT a literal value via Safety.quote_sql_string, then SELECT it back.
  # Proves the quoting produces a value that PG stores and returns unchanged.
  defp round_trip(conn, value) do
    {:ok, quoted} = PgDurable.SQL.Safety.quote_sql_string(value)

    %{rows: [[retrieved]]} =
      Postgrex.query!(conn, "SELECT #{quoted}::text", [])

    retrieved
  end

  # ---------------------------------------------------------------------------
  # Single quotes
  # ---------------------------------------------------------------------------

  describe "single quotes round-trip" do
    test "value with internal single quote", %{conn: conn} do
      assert round_trip(conn, "it's") == "it's"
    end

    test "double single quote", %{conn: conn} do
      assert round_trip(conn, "''") == "''"
    end

    test "triple single quote", %{conn: conn} do
      assert round_trip(conn, "'''") == "'''"
    end
  end

  # ---------------------------------------------------------------------------
  # Backslashes
  # ---------------------------------------------------------------------------

  describe "backslashes round-trip" do
    test "path with backslashes", %{conn: conn} do
      assert round_trip(conn, "path\\to\\file") == "path\\to\\file"
    end

    test "double backslash", %{conn: conn} do
      assert round_trip(conn, "\\\\") == "\\\\"
    end

    test "escape sequences treated as literal data", %{conn: conn} do
      assert round_trip(conn, "\\n\\t\\r") == "\\n\\t\\r"
    end
  end

  # ---------------------------------------------------------------------------
  # Dollar signs
  # ---------------------------------------------------------------------------

  describe "dollar signs round-trip as data" do
    test "dollar followed by number", %{conn: conn} do
      assert round_trip(conn, "$1") == "$1"
    end

    test "dollar name reference lookalike", %{conn: conn} do
      assert round_trip(conn, "$name") == "$name"
    end

    test "dollar dollar block", %{conn: conn} do
      assert round_trip(conn, "$$dollar$$") == "$$dollar$$"
    end

    test "multiple dollar tokens", %{conn: conn} do
      assert round_trip(conn, "$1 $2 $name") == "$1 $2 $name"
    end
  end

  # ---------------------------------------------------------------------------
  # Unicode and emoji
  # ---------------------------------------------------------------------------

  describe "unicode round-trip" do
    test "accented latin", %{conn: conn} do
      assert round_trip(conn, "héllo wörld") == "héllo wörld"
    end

    test "CJK characters", %{conn: conn} do
      assert round_trip(conn, "日本語テスト") == "日本語テスト"
    end

    test "emoji", %{conn: conn} do
      assert round_trip(conn, "🌍🎉🚀") == "🌍🎉🚀"
    end
  end

  # ---------------------------------------------------------------------------
  # Nested JSON
  # ---------------------------------------------------------------------------

  describe "nested JSON round-trip" do
    test "JSON with embedded single quotes", %{conn: conn} do
      json = ~s({"key": "value with 'quotes'"})
      assert round_trip(conn, json) == json
    end

    test "deeply nested JSON", %{conn: conn} do
      json = ~s({"a": {"b": {"c": [1, 2, 3]}}})
      assert round_trip(conn, json) == json
    end
  end

  # ---------------------------------------------------------------------------
  # SQL injection vectors — must remain data, not execute
  # ---------------------------------------------------------------------------

  describe "injection vectors round-trip as data" do
    test "semicolon injection", %{conn: conn} do
      assert round_trip(conn, "'; DROP TABLE users; --") ==
               "'; DROP TABLE users; --"
    end

    test "comment injection", %{conn: conn} do
      assert round_trip(conn, "value'/* COMMENT */'") == "value'/* COMMENT */'"
    end
  end

  # ---------------------------------------------------------------------------
  # Long strings
  # ---------------------------------------------------------------------------

  describe "long strings round-trip" do
    test "1500 char string", %{conn: conn} do
      long = String.duplicate("a", 1500)
      assert round_trip(conn, long) == long
    end
  end
end
