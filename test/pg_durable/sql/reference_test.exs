defmodule PgDurable.SQL.ReferenceTest do
  use ExUnit.Case, async: true

  alias PgDurable.Diagnostic
  alias PgDurable.Ref.{Column, Result, RowSet}
  alias PgDurable.SQL.Reference

  describe "render/1" do
    test "result renders to $name" do
      assert {:ok, "$users"} = Reference.render(%Result{name: "users"})
    end

    test "column renders to $name.column" do
      assert {:ok, "$users.id"} = Reference.render(%Column{result: "users", column: "id"})
    end

    test "row-set renders to $name.*" do
      assert {:ok, "$orders.*"} = Reference.render(%RowSet{name: "orders"})
    end

    test "atom names work" do
      assert {:ok, "$users"} = Reference.render(%Result{name: "users"})
    end

    test "rejects empty names" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: ""})
    end

    test "rejects names with spaces" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "my table"})
    end

    test "rejects names with dollar signs" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "table$name"})
    end

    test "rejects names with semicolons" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "users; DROP"})
    end

    test "rejects SQL comments in names" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "users--"})
    end

    test "rejects null bytes in names" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "users\0table"})
    end

    test "rejects non-reference structs" do
      assert {:error, %Diagnostic{code: :invalid_reference}} =
               Reference.render(%{name: "not a ref"})
    end
  end

  describe "validate_name/1" do
    test "accepts valid identifiers" do
      assert {:ok, "users"} = Reference.validate_name("users")
      assert {:ok, "my_table"} = Reference.validate_name("my_table")
      assert {:ok, "_private"} = Reference.validate_name("_private")
      assert {:ok, "Table123"} = Reference.validate_name("Table123")
    end

    test "converts atoms to strings" do
      assert {:ok, "users"} = Reference.validate_name(:users)
    end

    test "rejects empty strings" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Reference.validate_name("")
    end

    test "rejects names starting with digits" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("1table")
    end

    test "rejects names with spaces" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("my table")
    end

    test "rejects names with special characters" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("table-name")
      assert {:error, %Diagnostic{}} = Reference.validate_name("table.name")
      assert {:error, %Diagnostic{}} = Reference.validate_name("table\$name")
    end

    test "rejects non-string/non-atom input" do
      assert {:error, %Diagnostic{code: :invalid_name}} = Reference.validate_name(123)
    end
  end
end
