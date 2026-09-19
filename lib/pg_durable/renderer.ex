defmodule PgDurable.Renderer do
  @moduledoc """
  Renders workflow AST into pg_durable SQL expressions.

  Only constructs classified as v0.1 supported are rendered.
  Deferred/unsupported constructs return structured diagnostics.
  All string literal embedding routes through PgDurable.SQL.Safety.
  All result references route through PgDurable.SQL.Reference.
  """

  alias PgDurable.Diagnostic
  alias PgDurable.Workflow
  alias PgDurable.Workflow.Validator
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}
  alias PgDurable.SQL.{Safety, Reference}
  alias PgDurable.Ref.{Result, Column, RowSet}

  @doc """
  Render a workflow or node to a pg_durable graph expression.

  Returns the inner expression without the df.start() wrapper.
  """
  @spec to_expr(Workflow.t() | PgDurable.Node.t()) ::
          {:ok, String.t()} | {:error, [Diagnostic.t()]}
  def to_expr(%Workflow{root: root}) when not is_nil(root), do: to_expr(root)

  def to_expr(%Workflow{}),
    do: {:error, [Diagnostic.new(:missing_root, "Workflow has no root node")]}

  def to_expr(%Sql{sql: sql}) do
    case Safety.embed_node_sql(sql) do
      {:ok, embedded} -> {:ok, embedded}
      {:error, diag} -> {:error, [diag]}
    end
  end

  def to_expr(%Sequence{left: left, right: right}) do
    with {:ok, l} <- to_expr(left),
         {:ok, r} <- to_expr(right) do
      {:ok, "#{l} ~> #{r}"}
    end
  end

  def to_expr(%NamedResult{node: node, name: name}) do
    with {:ok, inner} <- to_expr(node) do
      case Safety.quote_sql_string(name) do
        {:ok, quoted_name} -> {:ok, "#{inner} |=> #{quoted_name}"}
        {:error, diag} -> {:error, [diag]}
      end
    end
  end

  def to_expr(%Join{left: left, right: right}) do
    with {:ok, l} <- to_expr(left),
         {:ok, r} <- to_expr(right) do
      {:ok, "#{l} & #{r}"}
    end
  end

  def to_expr(%If{condition: cond_sql, then: then_node, else: else_node}) do
    with {:ok, cond_quoted} <- Safety.quote_sql_string(cond_sql),
         {:ok, t} <- to_expr(then_node),
         {:ok, e} <- to_expr(else_node) do
      {:ok, "df.if(#{cond_quoted}, #{t}, #{e})"}
    end
  end

  def to_expr(%Sleep{seconds: s}) do
    {:ok, "df.sleep(#{s})"}
  end

  def to_expr(%WaitForSignal{signal_name: name, timeout: nil}) do
    case Safety.quote_sql_string(name) do
      {:ok, quoted} -> {:ok, "df.wait_for_signal(#{quoted})"}
      {:error, diag} -> {:error, [diag]}
    end
  end

  def to_expr(%WaitForSignal{signal_name: name, timeout: t}) do
    case Safety.quote_sql_string(name) do
      {:ok, quoted} -> {:ok, "df.wait_for_signal(#{quoted}, #{t})"}
      {:error, diag} -> {:error, [diag]}
    end
  end

  def to_expr(%RawExpr{expr: expr}) do
    {:ok, expr}
  end

  def to_expr(%Result{} = ref), do: render_ref(ref)
  def to_expr(%Column{} = ref), do: render_ref(ref)
  def to_expr(%RowSet{} = ref), do: render_ref(ref)

  def to_expr(other) do
    {:error, [Diagnostic.new(:unsupported_node, "Cannot render node: #{inspect(other)}")]}
  end

  defp render_ref(ref) do
    case Reference.render(ref) do
      {:ok, token} -> {:ok, token}
      {:error, diag} -> {:error, [diag]}
    end
  end

  @doc """
  Render a workflow to a complete SELECT df.start(...) SQL statement.
  """
  @spec to_start_sql(Workflow.t() | PgDurable.Node.t(), keyword()) ::
          {:ok, String.t()} | {:error, [Diagnostic.t()]}
  def to_start_sql(input, opts \\ []) do
    with {:ok, expr} <- to_expr(input) do
      label = Keyword.get(opts, :label)

      start_call =
        case label do
          nil -> "df.start(#{expr})"
          l -> "df.start(#{expr}, #{Safety.quote_sql_string(l) |> elem(1)})"
        end

      {:ok, "SELECT #{start_call}"}
    end
  end

  @doc """
  Alias for to_start_sql/2. Returns a complete SQL statement.
  """
  @spec to_sql(Workflow.t() | PgDurable.Node.t(), keyword()) ::
          {:ok, String.t()} | {:error, [Diagnostic.t()]}
  def to_sql(input, opts \\ []), do: to_start_sql(input, opts)

  @doc """
  Validate a workflow and return diagnostics.
  """
  @spec validate(Workflow.t()) :: :ok | [Diagnostic.t()]
  def validate(%Workflow{} = workflow), do: Validator.validate(workflow)
  def validate(_), do: [Diagnostic.new(:invalid_input, "Expected a Workflow struct")]
end
