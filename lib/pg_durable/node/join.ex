defmodule PgDurable.Node.Join do
  @moduledoc """
  Parallel join (`&` or `df.join`).
  """

  @type t :: %__MODULE__{
          left: PgDurable.Node.t(),
          right: PgDurable.Node.t()
        }

  defstruct [:left, :right]
end
