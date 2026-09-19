defmodule PgDurable.Workflow.Builder do
  @moduledoc """
  Builder functions for constructing workflow AST.

  All functions return structs. No SQL is generated until the renderer
  is invoked.
  """

  alias PgDurable.Workflow
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}

  @doc """
  Create a new workflow with a root node.
  """
  @spec new(keyword()) :: Workflow.t()
  def new(opts \\ []) do
    name = Keyword.fetch!(opts, :name)

    %Workflow{
      name: name,
      label: Keyword.get(opts, :label),
      root: Keyword.get(opts, :root),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Create a new workflow, returning `{:ok, workflow}` or `{:error, [Diagnostic]}`.

  Returns a diagnostic when `:name` is missing or not a binary string.
  """
  @spec new!(keyword()) :: {:ok, Workflow.t()} | {:error, [PgDurable.Diagnostic.t()]}
  def new!(opts) do
    case Keyword.get(opts, :name) do
      nil ->
        {:error, [PgDurable.Diagnostic.new(:missing_name, "Workflow name is required")]}

      name when not is_binary(name) ->
        {:error,
         [
           PgDurable.Diagnostic.new(
             :invalid_name,
             "Workflow name must be a string, got: #{inspect(name)}"
           )
         ]}

      name ->
        {:ok,
         %Workflow{
           name: name,
           label: Keyword.get(opts, :label),
           root: Keyword.get(opts, :root),
           metadata: Keyword.get(opts, :metadata, %{})
         }}
    end
  end

  @doc """
  Create a raw SQL node.
  """
  @spec sql(String.t(), keyword()) :: Sql.t()
  def sql(sql_text, opts \\ []) do
    %Sql{sql: sql_text, name: Keyword.get(opts, :name)}
  end

  @doc """
  Sequence two nodes: `left ~> right`.
  """
  @spec then(PgDurable.Node.t(), PgDurable.Node.t()) :: Sequence.t()
  def then(left, right) do
    %Sequence{left: left, right: right}
  end

  @doc """
  Capture a named result: `|=> name`.
  """
  @spec named(PgDurable.Node.t(), String.t()) :: NamedResult.t()
  def named(node, name) when is_binary(name) do
    %NamedResult{node: node, name: name}
  end

  @doc """
  Parallel join of two nodes: `left & right`.
  """
  @spec join(PgDurable.Node.t(), PgDurable.Node.t()) :: Join.t()
  def join(left, right) do
    %Join{left: left, right: right}
  end

  @doc """
  Conditional branch: `df.if(condition, then, else)`.
  """
  @spec if_(String.t(), PgDurable.Node.t(), PgDurable.Node.t()) :: If.t()
  def if_(condition, then_node, else_node) when is_binary(condition) do
    %If{condition: condition, then: then_node, else: else_node}
  end

  @doc """
  Timed pause: `df.sleep(seconds)`.
  """
  @spec sleep(number()) :: Sleep.t()
  def sleep(seconds) when is_number(seconds) and seconds >= 0 do
    %Sleep{seconds: seconds}
  end

  @doc """
  Block until signal received: `df.wait_for_signal(name)`.
  """
  @spec wait_for_signal(String.t(), keyword()) :: WaitForSignal.t()
  def wait_for_signal(signal_name, opts \\ []) when is_binary(signal_name) do
    %WaitForSignal{signal_name: signal_name, timeout: Keyword.get(opts, :timeout)}
  end

  @doc """
  Raw pg_durable expression (escape hatch).

  **Warning:** This bypasses the typed DSL. The expression is treated
  as developer-authored code. Do not embed user data without using
  the literal quoting layer.
  """
  @spec raw_expr(String.t()) :: RawExpr.t()
  def raw_expr(expr) when is_binary(expr) do
    %RawExpr{expr: expr}
  end

  @doc """
  Validate a workflow and render it to SQL in one step.

  Returns `{:ok, sql}` if valid, or `{:error, diagnostics}` with
  all validation errors found.
  """
  @spec validate_and_render(Workflow.t()) ::
          {:ok, String.t()} | {:error, [PgDurable.Diagnostic.t()]}
  def validate_and_render(%Workflow{} = workflow) do
    case PgDurable.Workflow.Validator.validate(workflow) do
      :ok ->
        case PgDurable.Renderer.to_start_sql(workflow) do
          {:ok, sql} -> {:ok, sql}
          {:error, diags} -> {:error, diags}
        end

      errors ->
        {:error, errors}
    end
  end
end
