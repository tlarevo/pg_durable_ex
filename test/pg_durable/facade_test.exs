defmodule PgDurable.FacadeTest do
  use ExUnit.Case, async: true

  alias PgDurable.Diagnostic
  alias PgDurable.Workflow
  alias PgDurable.Node.{Sql, Sequence, NamedResult, Join, If, Sleep, WaitForSignal, RawExpr}
  alias PgDurable.Ref.{Result, Column, RowSet}

  # ── new!/1 (diagnostic-first) ────────────────────────────────────

  describe "new!/1" do
    test "returns {:ok, workflow} for valid opts" do
      assert {:ok, %Workflow{name: "test"}} = PgDurable.new!(name: "test")
    end

    test "returns {:error, [Diagnostic]} when name is missing" do
      assert {:error, [%Diagnostic{code: :missing_name}]} = PgDurable.new!([])
    end

    test "returns {:error, [Diagnostic]} when name is not a string" do
      assert {:error, [%Diagnostic{code: :invalid_name}]} = PgDurable.new!(name: 123)
    end

    test "creates workflow with label and root" do
      root = PgDurable.sql("SELECT 1")

      assert {:ok, w} = PgDurable.new!(name: "test", label: "my-label", root: root)
      assert w.label == "my-label"
      assert %Sql{} = w.root
    end
  end

  # ── new/1 (raises) ──────────────────────────────────────────────

  describe "new/1" do
    test "creates workflow" do
      w = PgDurable.new(name: "test")
      assert %Workflow{name: "test"} = w
    end

    test "raises KeyError when name is missing" do
      assert_raise KeyError, fn -> PgDurable.new([]) end
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

  # ── ref/1, ref/2, rowset/1 (diagnostic-first) ───────────────────

  describe "ref/1" do
    test "returns {:ok, Result} for valid name" do
      assert {:ok, %Result{name: "users"}} = PgDurable.ref("users")
    end

    test "returns {:error, Diagnostic} for invalid name" do
      assert {:error, %Diagnostic{code: :invalid_name}} = PgDurable.ref("")
    end
  end

  describe "ref/2" do
    test "returns {:ok, Column} for valid names" do
      assert {:ok, %Column{result: "users", column: "email"}} = PgDurable.ref("users", "email")
    end

    test "returns {:error, Diagnostic} for invalid name" do
      assert {:error, %Diagnostic{code: :invalid_name}} = PgDurable.ref("", "email")
    end
  end

  describe "rowset/1" do
    test "returns {:ok, RowSet} for valid name" do
      assert {:ok, %RowSet{name: "orders"}} = PgDurable.rowset("orders")
    end

    test "returns {:error, Diagnostic} for invalid name" do
      assert {:error, %Diagnostic{code: :invalid_name}} = PgDurable.rowset("")
    end
  end

  # ── ref!/1, ref!/2, rowset!/1 (raising) ─────────────────────────

  describe "ref!/1" do
    test "returns Result for valid name" do
      assert %Result{name: "users"} = PgDurable.ref!("users")
    end

    test "raises ArgumentError for invalid name" do
      assert_raise ArgumentError, fn -> PgDurable.ref!("") end
    end
  end

  describe "ref!/2" do
    test "returns Column for valid names" do
      assert %Column{result: "users", column: "email"} = PgDurable.ref!("users", "email")
    end

    test "raises ArgumentError for invalid name" do
      assert_raise ArgumentError, fn -> PgDurable.ref!("", "email") end
    end
  end

  describe "rowset!/1" do
    test "returns RowSet for valid name" do
      assert %RowSet{name: "orders"} = PgDurable.rowset!("orders")
    end

    test "raises ArgumentError for invalid name" do
      assert_raise ArgumentError, fn -> PgDurable.rowset!("") end
    end
  end

  # ── to_expr/1 ───────────────────────────────────────────────────

  describe "to_expr/1" do
    test "renders a simple SQL node" do
      node = PgDurable.sql("SELECT 1")
      assert {:ok, "E'SELECT 1'"} = PgDurable.to_expr(node)
    end

    test "renders a workflow with root" do
      root = PgDurable.sql("SELECT 1")
      w = PgDurable.new(name: "test", root: root)
      assert {:ok, "E'SELECT 1'"} = PgDurable.to_expr(w)
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

  # ── to_sql/1 ────────────────────────────────────────────────────

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

  # ── to_start_sql/2 ──────────────────────────────────────────────

  describe "to_start_sql/2" do
    test "returns diagnostic for invalid label" do
      node = PgDurable.sql("SELECT 1")

      assert {:error, [%Diagnostic{code: :null_byte}]} =
               PgDurable.to_start_sql(node, label: "bad\0label")
    end
  end

  # ── validate/1 ──────────────────────────────────────────────────

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
      assert function_exported?(PgDurable, :new!, 1)
    end
  end
end
