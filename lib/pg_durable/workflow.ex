defmodule PgDurable.Workflow do
  @moduledoc """
  Root struct for a pg_durable workflow.

  A workflow contains a name, an optional label, and a root node
  that forms the workflow graph.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          label: String.t() | nil,
          root: PgDurable.Node.t(),
          metadata: map()
        }

  defstruct [:name, :label, :root, metadata: %{}]
end
