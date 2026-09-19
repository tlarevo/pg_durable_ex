defmodule PgDurable.RefTest do
  use ExUnit.Case, async: true

  alias PgDurable.Diagnostic
  alias PgDurable.Ref
  alias PgDurable.Ref.{Column, Result, RowSet}

  # ── result/1 (diagnostic-first) ──────────────────────────────────

  describe "result/1" do
    test "returns {:ok, Result} for valid string name" do
      assert {:ok, %Result{name: "users"}} = Ref.result("users")
    end

    test "returns {:ok, Result} for valid atom name" do
      assert {:ok, %Result{name: "users"}} = Ref.result(:users)
    end

    test "returns {:error, Diagnostic} for empty string" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.result("")
    end

    test "returns {:error, Diagnostic} for name with space" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.result("my table")
    end

    test "returns {:error, Diagnostic} for name starting with digit" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.result("1invalid")
    end
  end

  # ── column/2 (diagnostic-first) ──────────────────────────────────

  describe "column/2" do
    test "returns {:ok, Column} for valid names" do
      assert {:ok, %Column{result: "users", column: "id"}} = Ref.column("users", "id")
    end

    test "returns {:ok, Column} for valid atom names" do
      assert {:ok, %Column{result: "users", column: "id"}} = Ref.column(:users, :id)
    end

    test "returns {:error, Diagnostic} for invalid result name" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.column("", "id")
    end

    test "returns {:error, Diagnostic} for invalid column name" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.column("users", "col name")
    end
  end

  # ── rowset/1 (diagnostic-first) ──────────────────────────────────

  describe "rowset/1" do
    test "returns {:ok, RowSet} for valid name" do
      assert {:ok, %RowSet{name: "orders"}} = Ref.rowset("orders")
    end

    test "returns {:ok, RowSet} for valid atom name" do
      assert {:ok, %RowSet{name: "orders"}} = Ref.rowset(:orders)
    end

    test "returns {:error, Diagnostic} for empty string" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.rowset("")
    end

    test "returns {:error, Diagnostic} for name with space" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Ref.rowset("bad name")
    end
  end

  # ── Bang constructors ────────────────────────────────────────────

  describe "result!/1" do
    test "returns Result for valid name" do
      assert %Result{name: "users"} = Ref.result!("users")
    end

    test "raises ArgumentError for invalid name" do
      assert_raise ArgumentError, fn -> Ref.result!("") end
    end

    test "raises ArgumentError for name with space" do
      assert_raise ArgumentError, fn -> Ref.result!("bad name") end
    end
  end

  describe "column!/2" do
    test "returns Column for valid names" do
      assert %Column{result: "users", column: "id"} = Ref.column!("users", "id")
    end

    test "raises ArgumentError for invalid result name" do
      assert_raise ArgumentError, fn -> Ref.column!("", "id") end
    end

    test "raises ArgumentError for invalid column name" do
      assert_raise ArgumentError, fn -> Ref.column!("users", "col name") end
    end
  end

  describe "rowset!/1" do
    test "returns RowSet for valid name" do
      assert %RowSet{name: "orders"} = Ref.rowset!("orders")
    end

    test "raises ArgumentError for invalid name" do
      assert_raise ArgumentError, fn -> Ref.rowset!("") end
    end
  end

  # ── Atom/string ergonomics ───────────────────────────────────────

  describe "atom-to-string coercion" do
    test "result/1 accepts atom and returns string in struct" do
      assert {:ok, %Result{name: "users"}} = Ref.result(:users)
    end

    test "column/2 accepts atoms" do
      assert {:ok, %Column{result: "users", column: "id"}} = Ref.column(:users, :id)
    end

    test "rowset/1 accepts atom" do
      assert {:ok, %RowSet{name: "orders"}} = Ref.rowset(:orders)
    end
  end

  # ── Adversarial inputs ──────────────────────────────────────────

  describe "adversarial name inputs" do
    test "$ prefix is rejected" do
      assert {:error, _} = Ref.result("$fake")
      assert {:error, _} = Ref.result(:"$fake")
    end

    test "quotes in name are rejected" do
      assert {:error, _} = Ref.result(~s(my"name))
      assert {:error, _} = Ref.result(~s(my'name))
      assert {:error, _} = Ref.result(~s(`name`))
    end

    test "semicolons are rejected" do
      assert {:error, _} = Ref.result("name; DROP TABLE users")
    end

    test "SQL comments are rejected" do
      assert {:error, _} = Ref.result("name--comment")
      assert {:error, _} = Ref.result("name/*comment*/")
    end

    test "null bytes are rejected" do
      assert {:error, _} = Ref.result("name\0")
    end

    test "spaces are rejected" do
      assert {:error, _} = Ref.result("my table")
      assert {:error, _} = Ref.result(" name")
      assert {:error, _} = Ref.result("name ")
    end

    test "empty strings are rejected" do
      assert {:error, _} = Ref.result("")
      assert {:error, _} = Ref.column("", "id")
      assert {:error, _} = Ref.column("users", "")
    end

    test "dollar-prefixed user input cannot forge references" do
      assert {:error, _} = Ref.result("$fake")
      assert {:error, _} = Ref.rowset("$users")
      assert {:error, _} = Ref.column("$users", "$id")
    end

    test "special characters are rejected" do
      assert {:error, _} = Ref.result("user@name")
      assert {:error, _} = Ref.result("name{1}")
      assert {:error, _} = Ref.result("name/val")
      assert {:error, _} = Ref.result("name.name")
    end
  end
end
