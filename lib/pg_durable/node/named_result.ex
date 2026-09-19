defmodule PgDurable.Node.NamedResult do
  @moduledoc """
  Named result capture (`|=>`).
  """

  @type t :: %__MODULE__{
          node: PgDurable.Node.t(),
          name: String.t()
        }

  defstruct [:node, :name]
end
