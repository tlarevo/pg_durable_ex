defmodule PgDurable.Node.RawExpr do
  @moduledoc """
  Raw pg_durable expression pass-through (escape hatch).

  **Warning:** This is an advanced escape hatch. Raw expressions are
  treated as developer-authored code, not user data. Do not mix with
  user-provided runtime strings unless those pass through the literal
  quoting layer.
  """

  @type t :: %__MODULE__{
          expr: String.t()
        }

  defstruct [:expr]
end
