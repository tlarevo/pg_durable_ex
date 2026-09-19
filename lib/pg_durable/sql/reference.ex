defmodule PgDurable.SQL.Reference do
  @moduledoc """
  Renders typed reference structs into SQL-safe tokens ($name, $name.column, $name.*).
  """

  alias PgDurable.Diagnostic
  alias PgDurable.Ref.{Column, Result, RowSet}

  @name_regex ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/

  @doc """
  Renders a reference struct into its SQL token form.
  Validates all names before rendering.
  """
  @spec render(Result.t() | Column.t() | RowSet.t()) ::
          {:ok, String.t()} | {:error, Diagnostic.t()}
  def render(%Result{name: name}) do
    with {:ok, n} <- validate_name(name), do: {:ok, "$#{n}"}
  end

  def render(%Column{result: name, column: col}) do
    with {:ok, n} <- validate_name(name),
         {:ok, c} <- validate_name(col) do
      {:ok, "$#{n}.#{c}"}
    end
  end

  def render(%RowSet{name: name}) do
    with {:ok, n} <- validate_name(name), do: {:ok, "$#{n}.*"}
  end

  def render(other) do
    {:error,
     Diagnostic.new(
       :invalid_reference,
       "Expected a PgDurable.Ref struct, got: #{inspect(other)}"
     )}
  end

  @doc """
  Validates and normalizes a reference name. Converts atoms to strings.
  """
  @spec validate_name(String.t() | atom()) :: {:ok, String.t()} | {:error, Diagnostic.t()}
  def validate_name(name) when is_atom(name), do: name |> Atom.to_string() |> validate_name()

  def validate_name(name) when is_binary(name) do
    cond do
      name == "" ->
        {:error, Diagnostic.new(:invalid_name, "Name must not be empty")}

      String.contains?(name, "\0") ->
        {:error, Diagnostic.new(:invalid_name, "Name must not contain null bytes")}

      not Regex.match?(@name_regex, name) ->
        {:error,
         Diagnostic.new(
           :invalid_name,
           "Name must match /^[a-zA-Z_][a-zA-Z0-9_]*$/, got: #{inspect(name)}"
         )}

      true ->
        {:ok, name}
    end
  end

  def validate_name(other) do
    {:error,
     Diagnostic.new(
       :invalid_name,
       "Name must be a string or atom, got: #{inspect(other)}"
     )}
  end
end
