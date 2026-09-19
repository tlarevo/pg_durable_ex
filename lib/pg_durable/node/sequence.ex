defmodule PgDurable.Node.Sequence do
  @moduledoc """
  Sequential composition (`~>`).
  """

  @type t :: %__MODULE__{
          left: PgDurable.Node.t(),
          right: PgDurable.Node.t()
        }

  defstruct [:left, :right]
end
