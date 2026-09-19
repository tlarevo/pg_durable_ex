defmodule PgDurable.Workflow.Validator do
  @moduledoc """
  Validate workflow AST structure and naming.
  """

  alias PgDurable.Diagnostic
  alias PgDurable.Workflow
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}

  @valid_name_regex ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/

  @doc """
  Validate a workflow. Returns `:ok` or a list of `Diagnostic.t()`.
  """
  @spec validate(Workflow.t()) :: :ok | [Diagnostic.t()]
  def validate(%Workflow{name: name, root: root}) do
    errors = []

    errors =
      if invalid_workflow_name?(name),
        do: [
          Diagnostic.new(:invalid_workflow_name, "Workflow name must be identifier-like", %{
            name: name
          })
          | errors
        ],
        else: errors

    errors =
      if is_nil(root),
        do: [Diagnostic.new(:missing_root, "Workflow must have a root node") | errors],
        else: errors

    errors = if root, do: validate_node(root, errors), else: errors

    case errors do
      [] -> :ok
      errs -> Enum.reverse(errs)
    end
  end

  defp validate_node(%NamedResult{name: name}, errors) do
    if invalid_ref_name?(name),
      do: [
        Diagnostic.new(:invalid_named_result, "Named result name must be identifier-like", %{
          name: name
        })
        | errors
      ],
      else: errors
  end

  defp validate_node(%Sequence{left: left, right: right}, errors),
    do: errors |> validate_node(left) |> validate_node(right)

  defp validate_node(%Join{left: left, right: right}, errors),
    do: errors |> validate_node(left) |> validate_node(right)

  defp validate_node(%If{then: t, else: e}, errors),
    do: errors |> validate_node(t) |> validate_node(e)

  defp validate_node(%Sql{sql: sql}, errors) when is_binary(sql) and sql != "", do: errors

  defp validate_node(%Sql{}, errors),
    do: [Diagnostic.new(:invalid_sql_node, "SQL node must have non-empty SQL") | errors]

  defp validate_node(%Sleep{seconds: s}, errors) when is_number(s) and s >= 0, do: errors

  defp validate_node(%Sleep{}, errors),
    do: [Diagnostic.new(:invalid_sleep, "Sleep seconds must be a non-negative number") | errors]

  defp validate_node(%WaitForSignal{signal_name: name}, errors)
       when is_binary(name) and name != "",
       do: errors

  defp validate_node(%WaitForSignal{}, errors),
    do: [Diagnostic.new(:invalid_signal, "Signal name must be non-empty") | errors]

  defp validate_node(%RawExpr{expr: expr}, errors) when is_binary(expr) and expr != "", do: errors

  defp validate_node(%RawExpr{}, errors),
    do: [Diagnostic.new(:invalid_raw_expr, "Raw expression must be non-empty") | errors]

  defp validate_node(_, errors), do: errors

  defp invalid_workflow_name?(name) when is_binary(name) do
    name == "" or not Regex.match?(@valid_name_regex, name)
  end

  defp invalid_workflow_name?(_), do: true

  defp invalid_ref_name?(name) when is_binary(name) do
    name == "" or not Regex.match?(@valid_name_regex, name)
  end

  defp invalid_ref_name?(_), do: true
end
