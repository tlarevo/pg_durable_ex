defmodule PgDurable.Node do
  @moduledoc """
  Behaviour and type for all workflow graph nodes.
  """

  @type t ::
          PgDurable.Node.Sql.t()
          | PgDurable.Node.Sequence.t()
          | PgDurable.Node.NamedResult.t()
          | PgDurable.Node.Join.t()
          | PgDurable.Node.If.t()
          | PgDurable.Node.Sleep.t()
          | PgDurable.Node.WaitForSignal.t()
          | PgDurable.Node.RawExpr.t()
end
