defmodule PgDurable.Node.WaitForSignal do
  @moduledoc """
  Block until signal received (`df.wait_for_signal`).
  """

  @type t :: %__MODULE__{
          signal_name: String.t(),
          timeout: number() | nil
        }

  defstruct [:signal_name, :timeout]
end
