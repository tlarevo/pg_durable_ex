defmodule PgDurable do
  @moduledoc """
  Thin typed facade, compiler, and execution client for pg_durable.

  `pg_durable_ex` provides an Elixir-native API for building and executing
  durable workflows via PostgreSQL's pg_durable extension.

  ## Status

  **This library is experimental.** Upstream pg_durable is currently labeled
  Preview. pg_durable_ex remains experimental until both conformance and
  command-centre viability gates pass.

  ## Architecture

  - OTP supervises runtime processes.
  - pg_durable owns long-lived durable procedure/orchestration state.
  - Oban owns bounded asynchronous Elixir/application execution.
  - PostgreSQL/Ecto domain records own authoritative findings.
  - Provider executors own narrowly authorised external effects.

  Do not let two layers become authoritative for the same state.

  ## pg_durable version

  Primary development target: pg_durable v0.2.7.
  See `docs/compatibility/version_policy.md` for the full compatibility policy.
  """

  @spec version() :: String.t()
  def version, do: Mix.Project.config()[:version]
end
