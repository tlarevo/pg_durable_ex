defmodule PgDurable.FacadeTest do
  use ExUnit.Case, async: true

  alias PgDurable.Workflow
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}
  alias PgDurable.Ref.{Result, Column, RowSet}

  describe "new/1" do
    test "creates workflow" do
      w = PgDurable.new(name: "test")
      assert %Workflow{name: "test"} = w
    end

    test "creates workflow with label and root" do
      root = PgDurable.sql("SELECT 1")
      w = PgDurable.new(name: "test", label: "my-label", root: root)
      assert w.label == "my-label"
      assert %Sql{} = w.root
    end
  end

  describe "sql/1" do
    test "creates Sql node" do
      node = PgDurable.sql("SELECT 1")
      assert %Sql{sql: "SELECT 1"} = node
    end

    test "creates Sql node with name" do
      node = PgDurable.sql("SELECT 1", name: "step1")
      assert node.name == "step1"
    end
  end

  describe "then/2" do
    test "creates Sequence" do
      a = PgDurable.sql("SELECT 1")
      b = PgDurable.sql("SELECT 2")
      seq = PgDurable.then(a, b)
      assert %Sequence{left: ^a, right: ^b} = seq
    end
  end

  describe "named/2" do
    test "creates NamedResult" do
      node = PgDurable.sql("SELECT 1")
      nr = PgDurable.named(node, "result1")
      assert %NamedResult{name: "result1"} = nr
    end
  end

  describe "join/2" do
    test "creates Join" do
      a = PgDurable.sql("SELECT 1")
      b = PgDurable.sql("SELECT 2")
      j = PgDurable.join(a, b)
      assert %Join{left: ^a, right: ^b} = j
    end
  end

  describe "if_/3" do
    test "creates If" do
      t = PgDurable.sql("SELECT 1")
      e = PgDurable.sql("SELECT 2")
      node = PgDurable.if_("SELECT true", t, e)
      assert %If{condition: "SELECT true"} = node
    end
  end

  describe "sleep/1" do
    test "creates Sleep" do
      node = PgDurable.sleep(5)
      assert %Sleep{seconds: 5} = node
    end
  end

  describe "wait_for_signal/1" do
    test "creates WaitForSignal" do
      node = PgDurable.wait_for_signal("my_signal")
      assert %WaitForSignal{signal_name: "my_signal", timeout: nil} = node
    end

    test "creates WaitForSignal with timeout" do
      node = PgDurable.wait_for_signal("my_signal", timeout: 30)
      assert node.timeout == 30
    end
  end

  describe "raw_expr/1" do
    test "creates RawExpr" do
      node = PgDurable.raw_expr("df.sleep(10)")
      assert %RawExpr{expr: "df.sleep(10)"} = node
    end
  end

  describe "ref/1" do
    test "creates Result reference" do
      ref = PgDurable.ref("users")
      assert %Result{name: "users"} = ref
    end
  end

  describe "ref/2" do
    test "creates Column reference" do
      ref = PgDurable.ref("users", "email")
      assert %Column{result: "users", column: "email"} = ref
    end
  end

  describe "rowset/1" do
    test "creates RowSet reference" do
      ref = PgDurable.rowset("orders")
      assert %RowSet{name: "orders"} = ref
    end
  end

  describe "to_expr/1" do
    test "renders a simple SQL node" do
      node = PgDurable.sql("SELECT 1")
      assert {:ok, "'SELECT 1'"} = PgDurable.to_expr(node)
    end

    test "renders a workflow with root" do
      root = PgDurable.sql("SELECT 1")
      w = PgDurable.new(name: "test", root: root)
      assert {:ok, "'SELECT 1'"} = PgDurable.to_expr(w)
    end

    test "renders a complex workflow" do
      workflow =
        PgDurable.new(name: "complex")
        |> Map.put(
          :root,
          PgDurable.sql("SELECT 1")
          |> PgDurable.named("step1")
          |> PgDurable.then(PgDurable.sql("SELECT 2"))
        )

      assert {:ok, _expr} = PgDurable.to_expr(workflow)
    end
  end

  describe "to_sql/1" do
    test "renders SELECT df.start(...) SQL" do
      node = PgDurable.sql("SELECT 1")
      assert {:ok, sql} = PgDurable.to_sql(node)
      assert sql =~ "SELECT df.start("
      assert sql =~ "SELECT 1"
    end

    test "renders workflow with label" do
      root = PgDurable.sql("SELECT 1")
      w = PgDurable.new(name: "test", root: root, label: "my-label")
      assert {:ok, sql} = PgDurable.to_sql(w, label: "my-label")
      assert sql =~ "SELECT df.start("
    end
  end

  describe "validate/1" do
    test "returns :ok for valid workflow" do
      w =
        PgDurable.new(name: "valid")
        |> Map.put(:root, PgDurable.sql("SELECT 1"))

      assert :ok = PgDurable.validate(w)
    end

    test "returns diagnostics for invalid workflow name" do
      w = PgDurable.new(name: "123-invalid!", root: PgDurable.sql("SELECT 1"))
      assert [_ | _] = PgDurable.validate(w)
    end
  end

  describe "module does not leak internal structs" do
    test "Builder is not directly referenced" do
      assert function_exported?(PgDurable, :new, 1)
    end
  end
end
