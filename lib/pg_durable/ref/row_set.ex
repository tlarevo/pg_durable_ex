defmodule PgDurable.Ref.RowSet do
  @moduledoc """
  Reference to all columns (wildcard) of a result set.
  """

  @enforce_keys [:name]
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}
end
