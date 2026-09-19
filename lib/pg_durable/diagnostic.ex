defmodule PgDurable.Diagnostic do
  @moduledoc """
  Structured error for pg_durable library operations.
  """

  @enforce_keys [:code, :message]
  defstruct [:code, :message, severity: :error, details: %{}]

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          severity: :error | :warning,
          details: map()
        }

  @spec new(atom(), String.t(), map()) :: t()
  def new(code, message, details \\ %{}) do
    %__MODULE__{code: code, message: message, details: details}
  end

  @doc """
  Format a diagnostic for human-readable output.

  ## Examples

      iex> PgDurable.Diagnostic.format(%PgDurable.Diagnostic{code: :bad, message: "oh no", severity: :error})
      "[error] bad: oh no"

      iex> PgDurable.Diagnostic.format(%PgDurable.Diagnostic{code: :warn, message: "heads up", severity: :warning})
      "[warning] warn: heads up"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{code: code, message: message, severity: severity}) do
    "[#{severity}] #{code}: #{message}"
  end
end
