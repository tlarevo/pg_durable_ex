defmodule PgDurable.Ref do
  @moduledoc """
  Public API for creating typed references to result sets, columns, and row sets.
  """

  alias PgDurable.Ref.{Column, Result, RowSet}
  alias PgDurable.SQL.Reference

  @spec result(String.t() | atom()) :: Result.t()
  def result(name) do
    case Reference.validate_name(name) do
      {:ok, validated} -> %Result{name: validated}
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end

  @spec column(String.t() | atom(), String.t() | atom()) :: Column.t()
  def column(result_name, col_name) do
    with {:ok, r} <- Reference.validate_name(result_name),
         {:ok, c} <- Reference.validate_name(col_name) do
      %Column{result: r, column: c}
    else
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end

  @spec rowset(String.t() | atom()) :: RowSet.t()
  def rowset(name) do
    case Reference.validate_name(name) do
      {:ok, validated} -> %RowSet{name: validated}
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end
end
