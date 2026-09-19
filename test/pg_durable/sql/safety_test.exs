defmodule PgDurable.SQL.SafetyTest do
  use ExUnit.Case, async: true

  alias PgDurable.Diagnostic
  alias PgDurable.SQL.Safety

  # ---------------------------------------------------------------------------
  # quote_sql_string/1
  # ---------------------------------------------------------------------------

  describe "quote_sql_string/1" do
    test "wraps simple string in E-quoted single quotes" do
      assert {:ok, "E'hello'"} = Safety.quote_sql_string("hello")
    end

    test "escapes internal single quotes" do
      assert {:ok, "E'it''s'"} = Safety.quote_sql_string("it's")
    end

    test "backslashes are doubled (deterministic E'...' syntax)" do
      # Input: path\to\file (single backslashes)
      # E'...' doubles each backslash so PG interprets them as literal
      assert {:ok, "E'path\\\\to\\\\file'"} = Safety.quote_sql_string("path\\to\\file")
    end

    test "rejects null bytes" do
      assert {:error, %Diagnostic{code: :null_byte}} = Safety.quote_sql_string("hello\0world")
    end

    test "rejects non-string input" do
      assert {:error, %Diagnostic{code: :invalid_type}} = Safety.quote_sql_string(123)
    end

    test "handles empty string" do
      assert {:ok, "E''"} = Safety.quote_sql_string("")
    end

    test "prevents SQL injection" do
      malicious = "'; DROP TABLE users; --"
      assert {:ok, "E'''; DROP TABLE users; --'"} = Safety.quote_sql_string(malicious)
    end

    test "handles dollar signs" do
      assert {:ok, "E'$100'"} = Safety.quote_sql_string("$100")
    end

    test "handles unicode and emoji" do
      assert {:ok, "E'héllo wörld 🎉'"} = Safety.quote_sql_string("héllo wörld 🎉")
    end

    # --- adversarial: single quotes ---

    test "double single quote" do
      # "''" → each ' escaped to '' → E'''' → wrapped: E''''''
      assert {:ok, "E''''''"} = Safety.quote_sql_string("''")
    end

    test "triple single quote" do
      # "'''" → each ' escaped to '' → E'''''' → wrapped: E''''''''
      assert {:ok, "E''''''''"} = Safety.quote_sql_string("'''")
    end

    # --- adversarial: backslashes ---

    test "double backslash input produces quadruple in E'...' literal" do
      # Input: two backslashes (Elixir "\\\\" = two chars)
      # Each backslash doubled → four backslashes in the SQL literal
      assert {:ok, "E'\\\\\\\\'"} = Safety.quote_sql_string("\\\\")
    end

    test "backslash-n and backslash-t are escaped, not interpreted" do
      # Input: \n\t (four chars: backslash n backslash t)
      # Each backslash doubled → \\n\\t in the SQL literal
      assert {:ok, "E'\\\\n\\\\t'"} = Safety.quote_sql_string("\\n\\t")
    end

    # --- adversarial: SQL comments ---

    test "single-line comment" do
      assert {:ok, "E'-- comment'"} = Safety.quote_sql_string("-- comment")
    end

    test "block comment" do
      assert {:ok, "E'/* comment */'"} = Safety.quote_sql_string("/* comment */")
    end

    # --- adversarial: semicolons ---

    test "semicolon injection" do
      assert {:ok, "E'''; DROP TABLE'''"} = Safety.quote_sql_string("'; DROP TABLE'")
    end

    # --- adversarial: dollar signs ---

    test "dollar sign followed by number" do
      assert {:ok, "E'$1'"} = Safety.quote_sql_string("$1")
    end

    test "dollar sign name reference lookalike" do
      assert {:ok, "E'$name'"} = Safety.quote_sql_string("$name")
    end

    test "dollar dollar block" do
      assert {:ok, "E'$$dollar$$'"} = Safety.quote_sql_string("$$dollar$$")
    end

    # --- adversarial: Unicode ---

    test "accented latin" do
      assert {:ok, "E'héllo'"} = Safety.quote_sql_string("héllo")
    end

    test "CJK characters" do
      assert {:ok, "E'日本語'"} = Safety.quote_sql_string("日本語")
    end

    test "emoji" do
      assert {:ok, "E'🌍'"} = Safety.quote_sql_string("🌍")
    end

    # --- adversarial: nested JSON ---

    test "JSON with embedded single quotes" do
      json = ~s({"key": "value with 'quotes'"})
      assert {:ok, quoted} = Safety.quote_sql_string(json)
      assert String.starts_with?(quoted, "E'")
      assert String.ends_with?(quoted, "'")
      # The inner quotes are doubled
      assert String.contains?(quoted, "''")
    end

    # --- adversarial: long strings ---

    test "1000+ char string passes through" do
      long = String.duplicate("a", 1500)
      assert {:ok, result} = Safety.quote_sql_string(long)
      assert result == "E'#{long}'"
    end

    # --- adversarial: null byte rejection ---

    test "null byte rejected at start" do
      assert {:error, %Diagnostic{code: :null_byte}} = Safety.quote_sql_string("\0foo")
    end

    test "null byte rejected at end" do
      assert {:error, %Diagnostic{code: :null_byte}} = Safety.quote_sql_string("foo\0")
    end

    # --- adversarial: dollar sign strings not interpreted as references ---

    test "string starting with dollar is just data" do
      assert {:ok, "E'$ref'"} = Safety.quote_sql_string("$ref")
    end

    test "string that looks like parameter marker is just data" do
      assert {:ok, "E'$1 $2 $3'"} = Safety.quote_sql_string("$1 $2 $3")
    end
  end

  # ---------------------------------------------------------------------------
  # quote_literal/1
  # ---------------------------------------------------------------------------

  describe "quote_literal/1" do
    test "nil becomes NULL" do
      assert {:ok, "NULL"} = Safety.quote_literal(nil)
    end

    test "true becomes TRUE" do
      assert {:ok, "TRUE"} = Safety.quote_literal(true)
    end

    test "false becomes FALSE" do
      assert {:ok, "FALSE"} = Safety.quote_literal(false)
    end

    test "integers become decimal strings" do
      assert {:ok, "42"} = Safety.quote_literal(42)
      assert {:ok, "-7"} = Safety.quote_literal(-7)
      assert {:ok, "0"} = Safety.quote_literal(0)
    end

    test "floats become decimal strings" do
      assert {:ok, "3.14"} = Safety.quote_literal(3.14)
    end

    test "rejects NaN" do
      assert {:error, %Diagnostic{code: :invalid_float}} = Safety.quote_literal(:nan)
    end

    test "rejects Infinity" do
      assert {:error, %Diagnostic{code: :invalid_float}} = Safety.quote_literal(:infinity)
      assert {:error, %Diagnostic{code: :invalid_float}} = Safety.quote_literal(:neg_infinity)
    end

    test "strings are quoted with E'...' syntax" do
      assert {:ok, "E'hello'"} = Safety.quote_literal("hello")
    end

    test "dates get ::date cast" do
      assert {:ok, "E'2026-09-19'::date"} = Safety.quote_literal(~D[2026-09-19])
    end

    test "naive_date_times get ::timestamp cast" do
      assert {:ok, "E'2026-09-19 12:30:00'::timestamp"} =
               Safety.quote_literal(~N[2026-09-19 12:30:00])
    end

    test "date_times get ::timestamptz cast" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-09-19T12:30:00Z")
      assert {:ok, "E'2026-09-19 12:30:00Z'::timestamptz"} = Safety.quote_literal(dt)
    end

    test "maps become JSON with ::jsonb cast" do
      assert {:ok, "E'{\"a\":1}'::jsonb"} = Safety.quote_literal(%{"a" => 1})
    end

    test "lists become JSON with ::jsonb cast" do
      assert {:ok, "E'[1,2,3]'::jsonb"} = Safety.quote_literal([1, 2, 3])
    end

    test "rejects unsupported types" do
      assert {:error, %Diagnostic{code: :unsupported_type}} = Safety.quote_literal(self())
    end

    test "map with nested JSON containing quotes" do
      map = %{"key" => "it's a \"test\""}
      assert {:ok, result} = Safety.quote_literal(map)
      assert String.ends_with?(result, "::jsonb")
    end
  end

  # ---------------------------------------------------------------------------
  # quote_identifier/1
  # ---------------------------------------------------------------------------

  describe "quote_identifier/1" do
    test "wraps simple name in double quotes" do
      assert {:ok, "\"users\""} = Safety.quote_identifier("users")
    end

    test "escapes internal double quotes" do
      assert {:ok, "\"my\"\"table\""} = Safety.quote_identifier("my\"table")
    end

    test "rejects null bytes" do
      assert {:error, %Diagnostic{code: :null_byte}} = Safety.quote_identifier("col\0name")
    end

    test "accepts atoms" do
      assert {:ok, "\"users\""} = Safety.quote_identifier(:users)
    end

    test "rejects non-string/non-atom input" do
      assert {:error, %Diagnostic{code: :invalid_type}} = Safety.quote_identifier(123)
    end
  end

  # ---------------------------------------------------------------------------
  # embed_node_sql/1
  # ---------------------------------------------------------------------------

  describe "embed_node_sql/1" do
    test "quotes developer SQL as E'...' string literal" do
      assert {:ok, "E'SELECT 1'"} = Safety.embed_node_sql("SELECT 1")
    end

    test "rejects null bytes in embedded SQL" do
      assert {:error, %Diagnostic{code: :null_byte}} = Safety.embed_node_sql("SELECT\01")
    end
  end
end
