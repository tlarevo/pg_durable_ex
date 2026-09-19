defmodule PgDurable do
  @moduledoc """
  Public facade for pg_durable workflows.

  Build, render, and validate durable workflow graphs through a single
  module — no internal struct assembly required.

  ## Quick start

      import PgDurable

      workflow =
        new(name: "send_welcome")
        |> sql("SELECT * FROM users WHERE id = :user_id")
        |> named("user")
        |> then(sql("INSERT INTO emails (user_id, body) VALUES (:user_id, 'Welcome!')"))
        |> then(sleep(3600))
        |> then(wait_for_signal("payment_confirmed"))

      {:ok, expression} = to_expr(workflow)
      {:ok, sql} = to_sql(workflow)
      :ok = validate(workflow)

  ## References

      user_ref = ref("user")
      email_col = ref("email", "address")
      rows = rowset("orders")

  References can be passed to `to_expr/1` to render their pg_durable token
  without wrapping them in a workflow node.

  ## Escape hatch

      raw_expr("df.transform(result, {mode: 'compact'})")

  `raw_expr/1` embeds a literal pg_durable expression string. Do not
  interpolate user data — use the typed node constructors instead.
  """

  @vsn Mix.Project.config()[:version]

  @spec version() :: String.t()
  def version, do: @vsn

  # ── Workflow creation ──

  @doc """
  Create a new workflow.

  ## Options

    * `:name` (required) — workflow identifier
    * `:label` — optional human label
    * `:root` — optional root node
    * `:metadata` — optional metadata map
  """
  defdelegate new(opts), to: PgDurable.Workflow.Builder, as: :new

  @doc """
  Create a new workflow, returning `{:ok, workflow}` or `{:error, [Diagnostic]}`.

  Returns a diagnostic when `:name` is missing or not a binary string.
  """
  defdelegate new!(opts), to: PgDurable.Workflow.Builder, as: :new!

  # ── Node constructors ──

  @doc "Create a raw SQL node."
  defdelegate sql(sql, opts \\ []), to: PgDurable.Workflow.Builder, as: :sql

  @doc "Sequence two nodes: `left ~> right`."
  defdelegate then(left, right), to: PgDurable.Workflow.Builder, as: :then

  @doc "Capture a named result: `|=> name`."
  defdelegate named(node, name), to: PgDurable.Workflow.Builder, as: :named

  @doc "Parallel join of two nodes: `left & right`."
  defdelegate join(left, right), to: PgDurable.Workflow.Builder, as: :join

  @doc "Conditional branch: `df.if(condition, then, else)`."
  defdelegate if_(condition, then_node, else_node), to: PgDurable.Workflow.Builder, as: :if_

  @doc "Timed pause: `df.sleep(seconds)`."
  defdelegate sleep(seconds), to: PgDurable.Workflow.Builder, as: :sleep

  @doc "Block until signal received: `df.wait_for_signal(name)`."
  defdelegate wait_for_signal(name, opts \\ []),
    to: PgDurable.Workflow.Builder,
    as: :wait_for_signal

  @doc "Raw pg_durable expression (escape hatch). Do not embed user data."
  defdelegate raw_expr(expr), to: PgDurable.Workflow.Builder, as: :raw_expr

  # ── References ──

  @doc "Create a typed result reference, returning `{:ok, ref}` or `{:error, Diagnostic}`."
  defdelegate ref(name), to: PgDurable.Ref, as: :result

  @doc "Create a typed column reference, returning `{:ok, ref}` or `{:error, Diagnostic}`."
  defdelegate ref(name, column), to: PgDurable.Ref, as: :column

  @doc "Create a typed rowset reference, returning `{:ok, ref}` or `{:error, Diagnostic}`."
  defdelegate rowset(name), to: PgDurable.Ref, as: :rowset

  @doc "Create a typed result reference (raises on invalid name)."
  defdelegate ref!(name), to: PgDurable.Ref, as: :result!

  @doc "Create a typed column reference (raises on invalid name)."
  defdelegate ref!(name, column), to: PgDurable.Ref, as: :column!

  @doc "Create a typed rowset reference (raises on invalid name)."
  defdelegate rowset!(name), to: PgDurable.Ref, as: :rowset!

  # ── Rendering ──

  @doc "Render a workflow or node to a pg_durable expression string."
  defdelegate to_expr(workflow_or_node), to: PgDurable.Renderer

  @doc "Render to a complete `SELECT df.start(...)` SQL statement."
  defdelegate to_sql(workflow_or_node, opts \\ []), to: PgDurable.Renderer

  @doc "Alias for `to_sql/2`."
  defdelegate to_start_sql(workflow_or_node, opts \\ []), to: PgDurable.Renderer

  # ── Validation ──

  @doc "Validate a workflow. Returns `:ok` or a list of diagnostics."
  defdelegate validate(workflow), to: PgDurable.Renderer
end
