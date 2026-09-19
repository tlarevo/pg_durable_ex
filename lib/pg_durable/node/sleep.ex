defmodule PgDurable.Node.Sleep do
  @moduledoc """
  Timed pause (`df.sleep`).
  """

  @type t :: %__MODULE__{
          seconds: number()
        }

  defstruct [:seconds]
end
