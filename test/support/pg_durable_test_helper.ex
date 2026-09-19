defmodule PgDurable.TestSupport do
  @moduledoc """
  Helpers for pg_durable integration tests.

  Never uses system PostgreSQL. All tests run against disposable
  container instances on non-default ports.
  """

  @pg17_port 55_417
  @pg18_port 55_418
  @default_port @pg17_port
  # pg_durable always installs into the 'postgres' database
  @db_name "postgres"
  @db_user "postgres"
  @db_password "pg_durable_test"
  @max_retries 30
  @retry_interval_ms 1000

  @doc """
  Check if integration tests are enabled.

  Integration tests require PG_DURABLE_INTEGRATION=1 to run.
  """
  def integration_enabled? do
    System.get_env("PG_DURABLE_INTEGRATION") == "1"
  end

  @doc """
  Get the PostgreSQL port for the specified PG version.
  """
  def pg_port(version \\ nil) do
    version = version || pg_version()

    case version do
      17 -> @pg17_port
      18 -> @pg18_port
      _ -> @default_port
    end
  end

  @doc """
  Get the PG version from environment or default to 17.
  """
  def pg_version do
    case System.get_env("PG_DURABLE_PG_VERSION") do
      "17" -> 17
      "18" -> 18
      _ -> 17
    end
  end

  @doc """
  Get database connection options for the integration test database.
  """
  def db_opts do
    [
      hostname: "127.0.0.1",
      port: pg_port(),
      database: @db_name,
      username: @db_user,
      password: @db_password,
      backoff_type: :stop,
      max_restarts: 0
    ]
  end

  @doc """
  Connect to the test database.
  """
  def connect! do
    {:ok, conn} = Postgrex.start_link(db_opts())
    conn
  end

  @doc """
  Ensure pg_durable extension is ready. Retries for transient initialization.

  Raises with actionable error if:
  - Extension is missing
  - PostgreSQL major version < 17
  - Background worker not initialized after retries
  """
  def ensure_pg_durable_ready!(conn) do
    check_postgresql_version!(conn)
    check_extension_present!(conn)
    check_worker_ready!(conn)
    print_pg_durable_version(conn)
    :ok
  end

  defp check_postgresql_version!(conn) do
    %{rows: [[version_num]]} =
      Postgrex.query!(conn, "SHOW server_version_num", [])

    version_int = if is_binary(version_num), do: String.to_integer(version_num), else: version_num
    major = div(version_int, 10_000)

    if major < 17 do
      raise """
      pg_durable integration tests require PostgreSQL 17 or later.
      Detected PostgreSQL #{major} (server_version_num: #{version_num}).

      Use a disposable container instance on the correct port:
        docker compose -f docker/docker-compose.pg17.yml up -d
      """
    end
  end

  defp check_extension_present!(conn) do
    %{rows: [[exists]]} =
      Postgrex.query!(
        conn,
        """
        SELECT EXISTS (
          SELECT 1 FROM pg_extension WHERE extname = 'pg_durable'
        )
        """,
        []
      )

    unless exists do
      raise """
      pg_durable extension is not installed.

      Run the initialization SQL against the test database:
        docker exec -i pg_durable_test_pg17 psql -U pg_durable_test -d pg_durable_test < docker/pg_durable_init.sql

      Or start a fresh container which runs init automatically.
      """
    end
  end

  defp check_worker_ready!(conn) do
    # The pg_durable worker may not appear in pg_stat_activity with a
    # predictable backend_type name. Test readiness by calling df.start
    # directly — if it succeeds, the worker is operational.
    Enum.reduce_while(1..@max_retries, :not_ready, fn _attempt, _acc ->
      case Postgrex.query(conn, "SELECT df.start('SELECT 1')", []) do
        {:ok, %{rows: [[_id]]}} -> {:halt, :ready}
        _ ->
          Process.sleep(@retry_interval_ms)
          {:cont, :not_ready}
      end
    end)
    |> case do
      :ready ->
        :ok

      :not_ready ->
        raise """
        pg_durable background worker not initialized after #{@max_retries} retries.

        Check that shared_preload_libraries includes 'pg_durable' in postgresql.conf:
          shared_preload_libraries = 'pg_durable'

        Then restart PostgreSQL and re-run initialization.
        """
    end
  end

  defp print_pg_durable_version(conn) do
    try do
      %{rows: [[version]]} =
        Postgrex.query!(
          conn,
          "SELECT extversion FROM pg_extension WHERE extname = 'pg_durable'",
          []
        )

      IO.puts("  pg_durable extension version: #{version}")
    rescue
      _ -> IO.puts("  pg_durable extension version: unknown")
    end
  end
end
