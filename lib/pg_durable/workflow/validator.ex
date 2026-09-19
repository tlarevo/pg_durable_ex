defmodule PgDurable.Workflow.Validator do
  @moduledoc """
  Validate workflow AST structure and naming.

  Returns `:ok` for valid workflows, or a list of `Diagnostic.t()` with
  severity (`:error` for structural issues, `:warning` for semantic issues).
  """

  alias PgDurable.Diagnostic
  alias PgDurable.Workflow
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}

  @valid_name_regex ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/

  @doc """
  Validate a workflow. Returns `:ok` or a list of `Diagnostic.t()`.
  """
  @spec validate(Workflow.t()) :: :ok | [Diagnostic.t()]
  def validate(%Workflow{name: name, label: label, root: root}) do
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
      case label do
        nil ->
          errors

        label when is_binary(label) and label != "" ->
          errors

        _ ->
          [
            Diagnostic.new(:invalid_label, "Workflow label must be a non-empty string", %{
              label: label
            })
            | errors
          ]
      end

    errors =
      if is_nil(root),
        do: [Diagnostic.new(:missing_root, "Workflow must have a root node") | errors],
        else: errors

    # Structural validation with graph path
    errors = if root, do: validate_node(root, "root", errors), else: errors

    # Semantic validation (warnings) — skip when root is missing
    {defs, fwd_warnings} =
      if root do
        all_defs = collect_all_defs(root, "root", [])

        {_final_defined, fwd_warnings} =
          check_forward_refs(
            root,
            "root",
            MapSet.new(Enum.map(all_defs, &elem(&1, 0))),
            %{},
            []
          )

        {all_defs, fwd_warnings}
      else
        {[], []}
      end

    warnings = check_duplicate_names(fwd_warnings, defs)

    all = Enum.reverse(errors) ++ Enum.reverse(warnings)

    case all do
      [] -> :ok
      diags -> diags
    end
  end

  # --- Structural validation with graph path ---

  defp validate_node(%NamedResult{name: name, node: node}, path, errors) do
    child_path = "#{path} ~> named(#{name})"

    errors =
      if invalid_ref_name?(name),
        do: [
          Diagnostic.new(:invalid_named_result, "Named result name must be identifier-like", %{
            name: name,
            path: child_path
          })
          | errors
        ],
        else: errors

    validate_node(node, child_path, errors)
  end

  defp validate_node(%Sequence{left: left, right: right}, path, errors) do
    errors = validate_node(left, "#{path} ~> left", errors)
    validate_node(right, "#{path} ~> right", errors)
  end

  defp validate_node(%Join{left: left, right: right}, path, errors) do
    errors = validate_node(left, "#{path} ~> left", errors)
    validate_node(right, "#{path} ~> right", errors)
  end

  defp validate_node(%If{condition: cond, then: t, else: e}, path, errors) do
    errors =
      if is_nil(cond) or (is_binary(cond) and cond == ""),
        do: [
          Diagnostic.new(:invalid_if_condition, "If condition must be non-empty", %{
            path: path,
            suggestion: "Provide a SQL condition expression that returns a boolean"
          })
          | errors
        ],
        else: errors

    errors = validate_node(t, "#{path} ~> then", errors)
    validate_node(e, "#{path} ~> else", errors)
  end

  defp validate_node(%Sql{sql: sql}, _path, errors) when is_binary(sql) and sql != "", do: errors

  defp validate_node(%Sql{}, path, errors),
    do: [
      Diagnostic.new(:invalid_sql_node, "SQL node must have non-empty SQL", %{path: path})
      | errors
    ]

  defp validate_node(%Sleep{seconds: s}, _path, errors) when is_number(s) and s >= 0, do: errors

  defp validate_node(%Sleep{}, path, errors),
    do: [
      Diagnostic.new(:invalid_sleep, "Sleep seconds must be a non-negative number", %{
        path: path
      })
      | errors
    ]

  defp validate_node(%WaitForSignal{signal_name: name}, _path, errors)
       when is_binary(name) and name != "",
       do: errors

  defp validate_node(%WaitForSignal{}, path, errors),
    do: [
      Diagnostic.new(:invalid_signal, "Signal name must be non-empty", %{path: path})
      | errors
    ]

  defp validate_node(%RawExpr{expr: expr}, _path, errors)
       when is_binary(expr) and expr != "",
       do: errors

  defp validate_node(%RawExpr{}, path, errors),
    do: [
      Diagnostic.new(:invalid_raw_expr, "Raw expression must be non-empty", %{path: path})
      | errors
    ]

  defp validate_node(unknown, path, errors),
    do: [
      Diagnostic.new(:unknown_node, "Unknown node type: #{inspect(unknown)}", %{path: path})
      | errors
    ]

  # --- Pass 1: collect all named result definitions ---

  defp collect_all_defs(%NamedResult{name: name, node: node}, path, acc) do
    collect_all_defs(node, "#{path} ~> named(#{name})", [{name, path} | acc])
  end

  defp collect_all_defs(%Sequence{left: left, right: right}, path, acc) do
    acc = collect_all_defs(left, "#{path} ~> left", acc)
    collect_all_defs(right, "#{path} ~> right", acc)
  end

  defp collect_all_defs(%Join{left: left, right: right}, path, acc) do
    acc = collect_all_defs(left, "#{path} ~> left", acc)
    collect_all_defs(right, "#{path} ~> right", acc)
  end

  defp collect_all_defs(%If{then: t, else: e}, path, acc) do
    acc = collect_all_defs(t, "#{path} ~> then", acc)
    collect_all_defs(e, "#{path} ~> else", acc)
  end

  defp collect_all_defs(_, _path, acc), do: acc

  # --- Pass 2: walk tree checking refs against "defined so far" ---

  @ref_pattern ~r/\$([a-zA-Z_][a-zA-Z0-9_]*)/

  defp check_forward_refs(
         %NamedResult{name: name, node: node},
         path,
         all_names,
         defined,
         warnings
       ) do
    {defined, warnings} =
      check_forward_refs(node, "#{path} ~> named(#{name})", all_names, defined, warnings)

    {Map.put(defined, name, path), warnings}
  end

  defp check_forward_refs(%Sequence{left: left, right: right}, path, all_names, defined, warnings) do
    {defined, warnings} =
      check_forward_refs(left, "#{path} ~> left", all_names, defined, warnings)

    check_forward_refs(right, "#{path} ~> right", all_names, defined, warnings)
  end

  defp check_forward_refs(%Join{left: left, right: right}, path, all_names, defined, warnings) do
    {defined, warnings} =
      check_forward_refs(left, "#{path} ~> left", all_names, defined, warnings)

    check_forward_refs(right, "#{path} ~> right", all_names, defined, warnings)
  end

  defp check_forward_refs(%If{then: t, else: e}, path, all_names, defined, warnings) do
    {defined, warnings} =
      check_forward_refs(t, "#{path} ~> then", all_names, defined, warnings)

    check_forward_refs(e, "#{path} ~> else", all_names, defined, warnings)
  end

  defp check_forward_refs(%Sql{sql: sql}, path, all_names, defined, warnings) do
    found = Regex.scan(@ref_pattern, sql) |> Enum.map(&List.last/1) |> Enum.uniq()

    new_warnings =
      Enum.reduce(found, warnings, fn ref_name, acc ->
        if MapSet.member?(all_names, ref_name) and not Map.has_key?(defined, ref_name) do
          [
            %Diagnostic{
              code: :forward_reference,
              message: "Reference to '#{ref_name}' used before it is defined",
              severity: :warning,
              details: %{
                name: ref_name,
                used_at: path,
                suggestion:
                  "Move the reference after the named result definition, or reorder the workflow sequence."
              }
            }
            | acc
          ]
        else
          acc
        end
      end)

    {defined, new_warnings}
  end

  defp check_forward_refs(%WaitForSignal{}, _path, _all_names, defined, warnings),
    do: {defined, warnings}

  defp check_forward_refs(%Sleep{}, _path, _all_names, defined, warnings),
    do: {defined, warnings}

  defp check_forward_refs(%RawExpr{}, _path, _all_names, defined, warnings),
    do: {defined, warnings}

  defp check_forward_refs(_, _path, _all_names, defined, warnings),
    do: {defined, warnings}

  # --- Duplicate named result check ---

  defp check_duplicate_names(warnings, names) do
    names
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.reduce(warnings, fn {name, occurrences}, acc ->
      if length(occurrences) > 1 do
        paths = Enum.map_join(occurrences, ", ", &elem(&1, 1))

        [
          %Diagnostic{
            code: :duplicate_named_result,
            message: "Duplicate named result '#{name}' defined #{length(occurrences)} times",
            severity: :warning,
            details: %{
              name: name,
              paths: paths,
              suggestion:
                "Rename one of the duplicate named results to avoid ambiguity. Each named result in a workflow must be unique."
            }
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  # --- Name validation helpers ---

  defp invalid_workflow_name?(name) when is_binary(name) do
    name == "" or not Regex.match?(@valid_name_regex, name)
  end

  defp invalid_workflow_name?(_), do: true

  defp invalid_ref_name?(name) when is_binary(name) do
    name == "" or not Regex.match?(@valid_name_regex, name)
  end

  defp invalid_ref_name?(_), do: true
end
