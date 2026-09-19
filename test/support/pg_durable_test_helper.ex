defmodule PgDurable.TestSupport do
  @moduledoc """
  Helpers for pg_durable integration tests.

  Never uses system PostgreSQL. All tests run against disposable
  container instances on non-default ports.
  """

  @pg17_port_default 55_417
  @pg18_port_default 55_418
  @default_port @pg17_port_default
  # pg_durable always installs into the 'postgres' database
  @db_name "postgres"
  @db_user "postgres"
  @db_password "pg_durable_test"
  @max_retries 30
  @retry_interval_ms 1000
  @expected_pg_durable_version "0.2.7"

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
      17 ->
        System.get_env("PG_DURABLE_PG17_PORT", Integer.to_string(@pg17_port_default))
        |> String.to_integer()

      18 ->
        System.get_env("PG_DURABLE_PG18_PORT", Integer.to_string(@pg18_port_default))
        |> String.to_integer()

      _ ->
        @default_port
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
  Ensure pg_durable is ready for integration testing.

  Runs all three verification checks in order:
  1. PostgreSQL major version matches expected (from PG_DURABLE_PG_VERSION)
  2. pg_durable extension version matches #{@expected_pg_durable_version}
  3. Harness identity marker query succeeds
  4. df.start probe confirms background worker is operational
  """
  def ensure_pg_durable_ready!(conn) do
    verify_pg_version!(conn, pg_version())
    verify_pg_durable_version!(conn)
    harness_identity!(conn)
    check_worker_ready!(conn)
    :ok
  end

  @doc """
  Verify the running PostgreSQL major version matches the expected version.

  Raises if mismatch is detected.
  """
  def verify_pg_version!(conn, expected_major) do
    %{rows: [[version_num]]} =
      Postgrex.query!(conn, "SHOW server_version_num", [])

    version_int = if is_binary(version_num), do: String.to_integer(version_num), else: version_num
    actual_major = div(version_int, 10_000)

    unless actual_major == expected_major do
      raise """
      PostgreSQL major version mismatch.
      Expected: #{expected_major}, got: #{actual_major} (server_version_num: #{version_num}).

      Ensure the correct Docker Compose config is running:
        docker compose -f docker/docker-compose.pg#{expected_major}.yml up -d
      """
    end

    IO.puts("  PostgreSQL version verified: #{actual_major} (server_version_num: #{version_int})")
  end

  @doc """
  Verify the pg_durable extension version matches the expected version (#{@expected_pg_durable_version}).

  Raises if extension is missing or version mismatches.
  """
  def verify_pg_durable_version!(conn) do
    %{rows: [[version]]} =
      Postgrex.query!(
        conn,
        "SELECT extversion FROM pg_extension WHERE extname = 'pg_durable'",
        []
      )

    unless version == @expected_pg_durable_version do
      raise """
      pg_durable extension version mismatch.
      Expected: #{@expected_pg_durable_version}, got: #{version}.

      Ensure the correct pg_durable image tag is in use:
        ghcr.io/microsoft/pg_durable:v#{@expected_pg_durable_version}-pg#{pg_version()}
      """
    end

    IO.puts("  pg_durable extension version verified: #{version}")
  end

  @doc """
  Run a harness identity marker query to confirm the test harness is connected
  to the expected database and the pg_durable worker is accepting queries.
  """
  def harness_identity!(conn) do
    pg_ver = pg_version()
    pgd_ver = @expected_pg_durable_version
    marker = "pg_durable_ex_harness_v#{pgd_ver}_pg#{pg_ver}"

    Postgrex.query!(conn, """
    CREATE TABLE IF NOT EXISTS _pg_durable_ex_harness (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    """)

    Postgrex.query!(conn, """
    INSERT INTO _pg_durable_ex_harness (key, value)
    VALUES ('identity', '#{marker}')
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    """)

    %{rows: [[result]]} =
      Postgrex.query!(conn, """
      SELECT value FROM _pg_durable_ex_harness WHERE key = 'identity';
      """)

    unless result == marker do
      raise "Harness identity mismatch: expected '#{marker}', got '#{result}'."
    end

    IO.puts("  Harness identity verified: #{result}")
    :ok
  end

  defp check_worker_ready!(conn) do
    # The pg_durable worker may not appear in pg_stat_activity with a
    # predictable backend_type name. Test readiness by calling df.start
    # directly — if it succeeds, the worker is operational.
    Enum.reduce_while(1..@max_retries, :not_ready, fn _attempt, _acc ->
      case Postgrex.query(conn, "SELECT df.start('SELECT 1')", []) do
        {:ok, %{rows: [[_id]]}} ->
          {:halt, :ready}

        _ ->
          Process.sleep(@retry_interval_ms)
          {:cont, :not_ready}
      end
    end)
    |> case do
      :ready ->
        IO.puts("  pg_durable worker readiness confirmed via df.start probe")
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
end
