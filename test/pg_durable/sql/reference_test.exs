defmodule PgDurable.SQL.ReferenceTest do
  use ExUnit.Case, async: true

  alias PgDurable.Diagnostic
  alias PgDurable.Ref.{Column, Result, RowSet}
  alias PgDurable.SQL.Reference

  # ---------------------------------------------------------------------------
  # render/1
  # ---------------------------------------------------------------------------

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

    # --- adversarial: dollar signs ---

    test "dollar at start of name" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "$table"})
    end

    test "dollar at end of name" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "table$"})
    end

    test "multiple dollars in name" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "$a$b$c"})
    end

    test "dollar followed by digits (parameter marker lookalike)" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "$1"})
    end

    # --- adversarial: SQL comment syntax ---

    test "double dash in name" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "users--admin"})
    end

    test "block comment syntax in name" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "users/*injected*/"})
    end

    # --- adversarial: semicolons ---

    test "semicolon alone" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: ";"})
    end

    test "semicolon with statement fragments" do
      assert {:error, %Diagnostic{}} =
               Reference.render(%Result{name: "users; DROP TABLE; --"})
    end

    # --- adversarial: $name.* lookalikes that aren't valid identifiers ---

    test "name starting with digit" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "1table"})
    end

    test "name with hyphens" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "my-table"})
    end

    test "name with dots" do
      assert {:error, %Diagnostic{}} = Reference.render(%Result{name: "schema.table"})
    end

    # --- adversarial: very long names ---

    test "256 char name still validated" do
      long_name = String.duplicate("a", 256)
      # Long but valid — only alphanumeric + underscore, starts with letter
      assert {:ok, _} = Reference.validate_name(long_name)
    end

    test "257 char name still validated" do
      long_name = "a" <> String.duplicate("b", 256)
      assert {:ok, _} = Reference.validate_name(long_name)
    end

    # --- adversarial: Unicode names ---

    test "unicode letters rejected by name regex" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("héllo")
      assert {:error, %Diagnostic{}} = Reference.validate_name("日本語")
      assert {:error, %Diagnostic{}} = Reference.validate_name("🌍")
    end

    # --- adversarial: Column struct with bad parts ---

    test "rejects column with bad result name" do
      assert {:error, %Diagnostic{}} =
               Reference.render(%Column{result: "bad$name", column: "id"})
    end

    test "rejects column with bad column name" do
      assert {:error, %Diagnostic{}} =
               Reference.render(%Column{result: "users", column: "bad;col"})
    end
  end

  # ---------------------------------------------------------------------------
  # validate_name/1
  # ---------------------------------------------------------------------------

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

    # --- adversarial: dollar signs ---

    test "rejects dollar at start" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("$ref")
    end

    test "rejects dollar in middle" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("a$b")
    end

    test "rejects dollar at end" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("ref$")
    end

    # --- adversarial: SQL comment syntax ---

    test "rejects double dash" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("users--")
    end

    test "rejects block comment open" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("users/*")
    end

    # --- adversarial: semicolons ---

    test "rejects semicolon" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("users; DROP")
    end

    # --- adversarial: names that look like $name.* but aren't valid ---

    test "rejects name containing period" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("schema.table")
    end

    test "rejects name containing asterisk" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("all*")
    end

    # --- adversarial: very long names ---

    test "very long valid name passes" do
      name = String.duplicate("a", 500)
      assert {:ok, ^name} = Reference.validate_name(name)
    end

    # --- adversarial: null bytes ---

    test "rejects null byte at start" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("\0name")
    end

    test "rejects null byte at end" do
      assert {:error, %Diagnostic{}} = Reference.validate_name("name\0")
    end
  end
end
