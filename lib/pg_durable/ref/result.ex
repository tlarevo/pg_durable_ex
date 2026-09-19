defmodule PgDurable.Ref.Result do
  @moduledoc """
  Reference to a result set (CTE or node output) by name.
  """

  @enforce_keys [:name]
  defstruct [:name]

  @type t :: %__MODULE__{name: String.t()}
end
