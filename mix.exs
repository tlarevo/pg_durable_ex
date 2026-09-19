defmodule PgDurable.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/tlarevo/pg_durable_ex"

  def project do
    [
      app: :pg_durable_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "PgDurable",
      description: "Thin typed facade, compiler, and execution client for pg_durable.",
      license: nil,
      source_url: @source_url,
      docs: [main: "PgDurable", source_ref: "v#{@version}", extras: ["README.md"]],
      aliases: ["test.integration": "test --include pg_durable_integration"]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:postgrex, "~> 0.19", only: :test}
    ]
  end
end
