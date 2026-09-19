defmodule PgDurable.RendererTest do
  use ExUnit.Case, async: true

  alias PgDurable.Workflow.Builder
  alias PgDurable.Renderer
  alias PgDurable.Ref

  describe "to_expr/1" do
    test "simple SQL node" do
      node = Builder.sql("SELECT 1")
      assert {:ok, "'SELECT 1'"} = Renderer.to_expr(node)
    end

    test "SQL node with single quotes" do
      node = Builder.sql("SELECT 'hello'")
      assert {:ok, "'SELECT ''hello'''"} = Renderer.to_expr(node)
    end

    test "sequence of two SQL nodes" do
      node = Builder.then(Builder.sql("SELECT 1"), Builder.sql("SELECT 2"))
      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "~>"
      assert expr =~ "'SELECT 1'"
      assert expr =~ "'SELECT 2'"
    end

    test "named result" do
      node = Builder.named(Builder.sql("SELECT 1"), "my_result")
      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "|=>"
      assert expr =~ "'my_result'"
    end

    test "join" do
      node = Builder.join(Builder.sql("SELECT 1"), Builder.sql("SELECT 2"))
      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "&"
    end

    test "conditional if" do
      node =
        Builder.if_(
          "SELECT true",
          Builder.sql("SELECT 'yes'"),
          Builder.sql("SELECT 'no'")
        )

      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "df.if("
      assert expr =~ "SELECT true"
    end

    test "sleep" do
      node = Builder.sleep(5)
      assert {:ok, "df.sleep(5)"} = Renderer.to_expr(node)
    end

    test "wait_for_signal without timeout" do
      node = Builder.wait_for_signal("my_signal")
      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "df.wait_for_signal('my_signal')"
    end

    test "wait_for_signal with timeout" do
      node = Builder.wait_for_signal("my_signal", timeout: 30)
      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "df.wait_for_signal('my_signal', 30)"
    end

    test "raw expression passes through" do
      node = Builder.raw_expr("df.sleep(10)")
      assert {:ok, "df.sleep(10)"} = Renderer.to_expr(node)
    end

    test "result reference" do
      ref = Ref.result(:batch)
      assert {:ok, "$batch"} = Renderer.to_expr(ref)
    end

    test "column reference" do
      ref = Ref.column(:user, :id)
      assert {:ok, "$user.id"} = Renderer.to_expr(ref)
    end

    test "row-set reference" do
      ref = Ref.rowset(:batch)
      assert {:ok, "$batch.*"} = Renderer.to_expr(ref)
    end

    test "complex nested workflow" do
      node =
        Builder.then(
          Builder.named(Builder.sql("SELECT 1"), "step1"),
          Builder.join(
            Builder.sql("SELECT $step1.value"),
            Builder.sleep(1)
          )
        )

      assert {:ok, expr} = Renderer.to_expr(node)
      assert expr =~ "~>"
      assert expr =~ "|=>"
      assert expr =~ "&"
    end

    test "workflow root node" do
      w = Builder.new(name: "test", root: Builder.sql("SELECT 1"))
      assert {:ok, "'SELECT 1'"} = Renderer.to_expr(w)
    end

    test "workflow without root returns error" do
      w = Builder.new(name: "test")
      assert {:error, [_]} = Renderer.to_expr(w)
    end
  end

  describe "to_start_sql/2" do
    test "wraps expression in SELECT df.start" do
      node = Builder.sql("SELECT 1")
      assert {:ok, sql} = Renderer.to_start_sql(node)
      assert sql =~ "SELECT df.start('SELECT 1')"
    end

    test "with label" do
      node = Builder.sql("SELECT 1")
      assert {:ok, sql} = Renderer.to_start_sql(node, label: "my-label")
      assert sql =~ "SELECT df.start('SELECT 1', 'my-label')"
    end

    test "complex workflow" do
      node = Builder.then(Builder.sql("SELECT 1"), Builder.sql("SELECT 2"))
      assert {:ok, sql} = Renderer.to_start_sql(node)
      assert sql =~ "SELECT df.start("
    end
  end

  describe "to_sql/2" do
    test "is alias for to_start_sql" do
      node = Builder.sql("SELECT 1")
      assert {:ok, sql1} = Renderer.to_sql(node)
      assert {:ok, sql2} = Renderer.to_start_sql(node)
      assert sql1 == sql2
    end
  end

  describe "validate/1" do
    test "valid workflow" do
      w = Builder.new(name: "test", root: Builder.sql("SELECT 1"))
      assert :ok = Renderer.validate(w)
    end

    test "invalid workflow returns diagnostics" do
      w = Builder.new(name: "")
      assert [_ | _] = Renderer.validate(w)
    end
  end
end
