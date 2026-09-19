defmodule PgDurable.Ref.Column do
  @moduledoc """
  Reference to a specific column within a result set.
  """

  @enforce_keys [:result, :column]
  defstruct [:result, :column]

  @type t :: %__MODULE__{
          result: String.t(),
          column: String.t()
        }
end
