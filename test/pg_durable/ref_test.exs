defmodule PgDurable.RefTest do
  use ExUnit.Case, async: true

  alias PgDurable.Ref
  alias PgDurable.Ref.{Column, Result, RowSet}

  describe "result/1" do
    test "creates Result struct with valid string name" do
      assert %Result{name: "users"} = Ref.result("users")
    end

    test "rejects invalid name" do
      assert_raise ArgumentError, fn -> Ref.result("") end
      assert_raise ArgumentError, fn -> Ref.result("my table") end
      assert_raise ArgumentError, fn -> Ref.result("1invalid") end
    end
  end

  describe "column/2" do
    test "creates Column struct with valid names" do
      assert %Column{result: "users", column: "id"} = Ref.column("users", "id")
    end

    test "rejects invalid result name" do
      assert_raise ArgumentError, fn -> Ref.column("", "id") end
    end

    test "rejects invalid column name" do
      assert_raise ArgumentError, fn -> Ref.column("users", "col name") end
    end
  end

  describe "rowset/1" do
    test "creates RowSet struct with valid name" do
      assert %RowSet{name: "orders"} = Ref.rowset("orders")
    end

    test "rejects invalid name" do
      assert_raise ArgumentError, fn -> Ref.rowset("") end
      assert_raise ArgumentError, fn -> Ref.rowset("bad name") end
    end
  end
end
