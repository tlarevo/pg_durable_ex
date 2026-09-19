defmodule PgDurable.Ref do
  @moduledoc """
  Public API for creating typed references to result sets, columns, and row sets.
  """

  alias PgDurable.Diagnostic
  alias PgDurable.Ref.{Column, Result, RowSet}
  alias PgDurable.SQL.Reference

  @type ok_ref ::
          {:ok, Result.t()} | {:ok, Column.t()} | {:ok, RowSet.t()}

  @doc """
  Creates a `Result` reference, returning `{:ok, struct}` or `{:error, Diagnostic}`.
  """
  @spec result(String.t() | atom()) :: ok_ref | {:error, Diagnostic.t()}
  def result(name) do
    case Reference.validate_name(name) do
      {:ok, validated} -> {:ok, %Result{name: validated}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Creates a `Column` reference, returning `{:ok, struct}` or `{:error, Diagnostic}`.
  """
  @spec column(String.t() | atom(), String.t() | atom()) :: ok_ref | {:error, Diagnostic.t()}
  def column(result_name, col_name) do
    with {:ok, r} <- Reference.validate_name(result_name),
         {:ok, c} <- Reference.validate_name(col_name) do
      {:ok, %Column{result: r, column: c}}
    end
  end

  @doc """
  Creates a `RowSet` reference, returning `{:ok, struct}` or `{:error, Diagnostic}`.
  """
  @spec rowset(String.t() | atom()) :: ok_ref | {:error, Diagnostic.t()}
  def rowset(name) do
    case Reference.validate_name(name) do
      {:ok, validated} -> {:ok, %RowSet{name: validated}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Creates a `Result` reference, raising `ArgumentError` on invalid input.
  """
  @spec result!(String.t() | atom()) :: Result.t()
  def result!(name) do
    case result(name) do
      {:ok, ref} -> ref
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end

  @doc """
  Creates a `Column` reference, raising `ArgumentError` on invalid input.
  """
  @spec column!(String.t() | atom(), String.t() | atom()) :: Column.t()
  def column!(result_name, col_name) do
    case column(result_name, col_name) do
      {:ok, ref} -> ref
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end

  @doc """
  Creates a `RowSet` reference, raising `ArgumentError` on invalid input.
  """
  @spec rowset!(String.t() | atom()) :: RowSet.t()
  def rowset!(name) do
    case rowset(name) do
      {:ok, ref} -> ref
      {:error, diag} -> raise ArgumentError, message: diag.message
    end
  end
end
