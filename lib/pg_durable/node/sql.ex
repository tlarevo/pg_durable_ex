defmodule PgDurable.Node.Sql do
  @moduledoc """
  Developer-authored SQL node.
  """

  @type t :: %__MODULE__{
          sql: String.t(),
          name: String.t() | nil
        }

  defstruct [:sql, :name]
end
