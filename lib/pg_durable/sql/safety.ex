defmodule PgDurable.SQL.Safety do
  @moduledoc """
  Centralized SQL safety: quoting, escaping, and literal embedding.

  All SQL string literals and identifiers produced by this library pass through
  these functions. They reject null bytes, escape injection vectors, and enforce
  type-appropriate formatting.

  See `docs/security/sql_safety.md` for the trust model.
  """

  alias PgDurable.Diagnostic

  @doc """
  Wraps a string in PostgreSQL single quotes, escaping internal single quotes
  and backslashes. Rejects null bytes and non-binary input.

  Returns `{:ok, "'escaped_string'"}` or `{:error, Diagnostic.t()}`.
  """
  @spec quote_sql_string(String.t()) :: {:ok, String.t()} | {:error, Diagnostic.t()}
  def quote_sql_string(value) when not is_binary(value) do
    {:error, Diagnostic.new(:invalid_type, "Expected binary, got: #{inspect(value)}")}
  end

  def quote_sql_string(value) do
    if String.contains?(value, "\0") do
      {:error, Diagnostic.new(:null_byte, "String must not contain null bytes")}
    else
      escaped =
        value
        |> String.replace("\\", "\\\\")
        |> String.replace("'", "''")

      {:ok, "'#{escaped}'"}
    end
  end

  @doc """
  Converts an Elixir term to a safe SQL literal.

  - `nil` → `NULL`
  - `true`/`false` → `TRUE`/`FALSE`
  - integers → decimal string
  - floats → decimal string (rejects NaN/Infinity)
  - binaries → via `quote_sql_string/1`
  - `Date` → literal with `::date` cast
  - `NaiveDateTime` → literal with `::timestamp` cast
  - `DateTime` → literal with `::timestamptz` cast
  - maps/lists → JSON-encoded then quoted, with `::jsonb` cast
  """
  @spec quote_literal(term()) :: {:ok, String.t()} | {:error, Diagnostic.t()}
  def quote_literal(nil), do: {:ok, "NULL"}
  def quote_literal(true), do: {:ok, "TRUE"}
  def quote_literal(false), do: {:ok, "FALSE"}

  def quote_literal(value) when is_integer(value) do
    {:ok, Integer.to_string(value)}
  end

  def quote_literal(:nan) do
    {:error, Diagnostic.new(:invalid_float, "Float value is NaN")}
  end

  def quote_literal(:infinity) do
    {:error, Diagnostic.new(:invalid_float, "Float value is Infinity")}
  end

  def quote_literal(:neg_infinity) do
    {:error, Diagnostic.new(:invalid_float, "Float value is -Infinity")}
  end

  def quote_literal(value) when is_float(value) do
    {:ok, Float.to_string(value)}
  end

  def quote_literal(value) when is_binary(value) do
    with {:ok, quoted} <- quote_sql_string(value) do
      {:ok, quoted}
    end
  end

  def quote_literal(%Date{} = date) do
    with {:ok, quoted} <- quote_sql_string(Date.to_string(date)) do
      {:ok, "#{quoted}::date"}
    end
  end

  def quote_literal(%NaiveDateTime{} = ndt) do
    with {:ok, quoted} <- quote_sql_string(NaiveDateTime.to_string(ndt)) do
      {:ok, "#{quoted}::timestamp"}
    end
  end

  def quote_literal(%DateTime{} = dt) do
    with {:ok, quoted} <- quote_sql_string(DateTime.to_string(dt)) do
      {:ok, "#{quoted}::timestamptz"}
    end
  end

  def quote_literal(value) when is_map(value) or is_list(value) do
    encoded =
      value
      |> Jason.encode!()
      |> quote_sql_string()

    with {:ok, quoted} <- encoded do
      {:ok, "#{quoted}::jsonb"}
    end
  end

  def quote_literal(value) do
    {:error,
     Diagnostic.new(
       :unsupported_type,
       "Cannot convert to SQL literal: #{inspect(value)}"
     )}
  end

  @doc """
  Double-quotes a table or column name for safe use in SQL.

  Accepts strings or atoms. Rejects null bytes and non-valid inputs.

  Returns `{:ok, "\"name\""}` or `{:error, Diagnostic.t()}`.
  """
  @spec quote_identifier(String.t() | atom()) :: {:ok, String.t()} | {:error, Diagnostic.t()}
  def quote_identifier(value) when is_atom(value) do
    value |> Atom.to_string() |> quote_identifier()
  end

  def quote_identifier(value) when not is_binary(value) do
    {:error, Diagnostic.new(:invalid_type, "Expected string or atom, got: #{inspect(value)}")}
  end

  def quote_identifier(value) do
    if String.contains?(value, "\0") do
      {:error, Diagnostic.new(:null_byte, "Identifier must not contain null bytes")}
    else
      escaped = String.replace(value, "\"", "\"\"")
      {:ok, "\"#{escaped}\""}
    end
  end

  @doc """
  Wraps developer-provided SQL as a string literal via `quote_sql_string/1`.

  This is an escape hatch — it quotes the value but the caller is responsible
  for the SQL's correctness. Use for trusted, developer-authored SQL fragments
  only.
  """
  @spec embed_node_sql(String.t()) :: {:ok, String.t()} | {:error, Diagnostic.t()}
  def embed_node_sql(sql) do
    quote_sql_string(sql)
  end
end
