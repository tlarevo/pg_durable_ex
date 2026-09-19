defmodule PgDurable.WorkflowTest do
  use ExUnit.Case, async: true

  alias PgDurable.Workflow
  alias PgDurable.Workflow.Builder
  alias PgDurable.Workflow.Validator
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}

  describe "Builder" do
    test "new/1 creates workflow" do
      w = Builder.new(name: "test")
      assert %Workflow{name: "test"} = w
      assert is_nil(w.root)
    end

    test "new/1 with label and root" do
      root = Builder.sql("SELECT 1")
      w = Builder.new(name: "test", label: "my-label", root: root)
      assert w.label == "my-label"
      assert %Sql{} = w.root
    end

    test "sql/1 creates Sql node" do
      node = Builder.sql("SELECT 1")
      assert %Sql{sql: "SELECT 1"} = node
    end

    test "sql/2 with name" do
      node = Builder.sql("SELECT 1", name: "step1")
      assert node.name == "step1"
    end

    test "then/2 creates Sequence" do
      a = Builder.sql("SELECT 1")
      b = Builder.sql("SELECT 2")
      seq = Builder.then(a, b)
      assert %Sequence{left: ^a, right: ^b} = seq
    end

    test "named/2 creates NamedResult" do
      node = Builder.sql("SELECT 1")
      nr = Builder.named(node, "result1")
      assert %NamedResult{name: "result1"} = nr
    end

    test "join/2 creates Join" do
      a = Builder.sql("SELECT 1")
      b = Builder.sql("SELECT 2")
      j = Builder.join(a, b)
      assert %Join{left: ^a, right: ^b} = j
    end

    test "if_/3 creates If" do
      t = Builder.sql("SELECT 1")
      e = Builder.sql("SELECT 2")
      node = Builder.if_("SELECT true", t, e)
      assert %If{condition: "SELECT true"} = node
    end

    test "sleep/1 creates Sleep" do
      node = Builder.sleep(5)
      assert %Sleep{seconds: 5} = node
    end

    test "wait_for_signal/1 creates WaitForSignal" do
      node = Builder.wait_for_signal("my_signal")
      assert %WaitForSignal{signal_name: "my_signal", timeout: nil} = node
    end

    test "wait_for_signal/2 with timeout" do
      node = Builder.wait_for_signal("my_signal", timeout: 30)
      assert node.timeout == 30
    end

    test "raw_expr/1 creates RawExpr" do
      node = Builder.raw_expr("df.sleep(10)")
      assert %RawExpr{expr: "df.sleep(10)"} = node
    end

    test "complex workflow can be composed" do
      w =
        Builder.new(name: "complex")
        |> Map.put(
          :root,
          Builder.then(
            Builder.named(Builder.sql("SELECT 1"), "step1"),
            Builder.then(
              Builder.join(
                Builder.sql("SELECT $step1.value"),
                Builder.sleep(1)
              ),
              Builder.if_(
                "SELECT $step1.value > 0",
                Builder.sql("SELECT 'yes'"),
                Builder.sql("SELECT 'no'")
              )
            )
          )
        )

      assert %Workflow{name: "complex"} = w
      assert %Sequence{} = w.root
    end
  end

  describe "Validator" do
    test "valid workflow returns :ok" do
      w = Builder.new(name: "test", root: Builder.sql("SELECT 1"))
      assert :ok = Validator.validate(w)
    end

    test "empty name is invalid" do
      w = Builder.new(name: "", root: Builder.sql("SELECT 1"))
      assert [_diag] = Validator.validate(w)
    end

    test "name with spaces is invalid" do
      w = Builder.new(name: "my workflow", root: Builder.sql("SELECT 1"))
      assert [_diag] = Validator.validate(w)
    end

    test "missing root is invalid" do
      w = Builder.new(name: "test")
      assert [_diag] = Validator.validate(w)
    end

    test "invalid named result name" do
      nr = Builder.named(Builder.sql("SELECT 1"), "bad name")
      w = Builder.new(name: "test", root: nr)
      assert [_diag] = Validator.validate(w)
    end

    test "empty SQL node is invalid" do
      node = %PgDurable.Node.Sql{sql: ""}
      w = Builder.new(name: "test", root: node)
      assert [_diag] = Validator.validate(w)
    end

    test "negative sleep is invalid" do
      node = %PgDurable.Node.Sleep{seconds: -1}
      w = Builder.new(name: "test", root: node)
      assert [_diag] = Validator.validate(w)
    end
  end
end
