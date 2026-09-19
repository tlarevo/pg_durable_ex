defmodule PgDurable.Node.If do
  @moduledoc """
  Conditional branch (`df.if`).
  """

  @type t :: %__MODULE__{
          condition: String.t(),
          then: PgDurable.Node.t(),
          else: PgDurable.Node.t()
        }

  defstruct [:condition, :then, :else]
end
