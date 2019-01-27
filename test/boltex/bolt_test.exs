defmodule Boltex.BoltTest do
  use Boltex.IntegrationCase
  alias Boltex.Bolt

  test "works for small queries", %{port: port} do
    string = Enum.to_list(0..100) |> Enum.join()

    query = """
      RETURN {string} as string
    """

    params = %{string: string}

    [{:success, _} | records] = Bolt.run_statement(:gen_tcp, port, query, params)

    assert [record: [^string], success: _] = records
  end

  test "works for big queries", %{port: port} do
    string = Enum.to_list(0..25_000) |> Enum.join()

    query = """
      RETURN {string} as string
    """

    params = %{string: string}

    [{:success, _} | records] = Bolt.run_statement(:gen_tcp, port, query, params)

    assert [record: [^string], success: _] = records
  end

  test "returns errors for wrong cypher queris", %{port: port} do
    assert %Boltex.Error{type: :cypher_error} = Bolt.run_statement(:gen_tcp, port, "What?")
  end

  test "allows to recover from error with ack_failure for bolt v1 & v2", %{
    port: port,
    bolt_version: bolt_version
  } do
    if bolt_version <= 2 do
      assert %Boltex.Error{type: :cypher_error} = Bolt.run_statement(:gen_tcp, port, "What?")
      assert :ok = Bolt.ack_failure(:gen_tcp, port)
      assert [{:success, _} | _] = Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")
    end
  end

  # RESET doesn't exists in Bolt V3!
  test "allows to recover from error with reset", %{
    port: port
  } do
    assert %Boltex.Error{type: :cypher_error} = Bolt.run_statement(:gen_tcp, port, "What?")
    assert :ok = Bolt.reset(:gen_tcp, port)
    assert [{:success, _} | _] = Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")
  end

  test "returns proper error when using a bad session", %{port: port} do
    assert %Boltex.Error{type: :cypher_error} = Bolt.run_statement(:gen_tcp, port, "What?")
    error = Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")

    assert %Boltex.Error{} = error
    assert error.message =~ ~r/The session is in a failed state/
  end

  test "returns proper error when misusing ack_failure and reset", %{port: port} do
    assert %Boltex.Error{} = Bolt.ack_failure(:gen_tcp, port)
    :gen_tcp.close(port)
    assert %Boltex.Error{} = Bolt.reset(:gen_tcp, port)
  end

  test "returns proper error when using a closed port", %{port: port} do
    :gen_tcp.close(port)

    assert %Boltex.Error{type: :connection_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")
  end

  test "an invalid parameter value yields an error", %{port: port} do
    cypher = "MATCH (n:Person {invalid: {an_elixir_datetime}}) RETURN TRUE"

    assert_raise Boltex.PackStream.EncodeError, ~r/^unable to encode value: /i, fn ->
      Bolt.run_statement(:gen_tcp, port, cypher, %{an_elixir_datetime: DateTime.utc_now()})
    end
  end

  test "RUN with metadata (Bolt >= 3)", %{port: port, bolt_version: bolt_version} do
    if bolt_version >= 3 do
      assert [{:success, _}, {:record, _}, {:success, _}] =
               Bolt.run_statement_with_metadata(:gen_tcp, port, "RETURN 1 AS num", %{}, %{})

      metadata = %{
        tx_timeout: 1000,
        bookmarks: ["neo4j:bookmark:v1:tx16732"],
        tx_metadata: %{
          name: "my_tx"
        }
      }

      assert [{:success, _}, {:record, _}, {:success, _}] =
               Bolt.run_statement_with_metadata(:gen_tcp, port, "RETURN 1 AS num", %{}, metadata)
    end
  end

  test "Transactions work differently in v3", %{port: _port, bolt_version: _bolt_version} do
  end

  test "Temporal / spatial types does not work prior to bolt version 2",
       %{
         port: port,
         bolt_version: bolt_version
       } do
    test_spatial_and_temporal(port, bolt_version)
  end

  def test_transactions(port, bolt_version) when bolt_version <= 2 do
    # Works within a transaction
    assert [{:success, _}, {:success, _}] = Bolt.run_statement(:gen_tcp, port, "BEGIN")
    assert [{:success, _} | _] = Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")
    assert [{:success, _}, {:success, _}] = Bolt.run_statement(:gen_tcp, port, "COMMIT")

    # works with rolled-back transactions
    assert [{:success, _}, {:success, _}] = Bolt.run_statement(:gen_tcp, port, "BEGIN")
    assert [{:success, _} | _] = Bolt.run_statement(:gen_tcp, port, "RETURN 1 as num")
    assert [{:success, _}, {:success, _}] = Bolt.run_statement(:gen_tcp, port, "ROLLBACK")
  end

  def test_transactions(_port, _) do
  end

  @doc """
  Test valid returns for Bolt V1.
  """
  def test_spatial_and_temporal(port, 1) do
    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN date('2018-01-01') as d")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN time('12:45:30.25+01:00') AS t")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN local_time('12:45:30.25') AS t")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN duration('P1Y3M34DT54.00000555S') AS d")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN localdatetime('2018-04-05T12:34:00.543') AS d"
             )

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN datetime('2018-04-05T12:34:23.543+01:00') AS d"
             )

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN datetime('2018-04-05T12:34:23.543[Europe/Berlin]') AS d"
             )

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN point({x: 40, y: 45}) AS p")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN point({longitude: 40, latitude: 45}) AS p"
             )

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(:gen_tcp, port, "RETURN point({x: 40, y: 45, z: 150}) AS p")

    :ok = Bolt.ack_failure(:gen_tcp, port)

    assert %Boltex.Error{type: :cypher_error} =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN point({longitude: 40, latitude: 45, height: 150}) AS p"
             )
  end

  @doc """
  Test valid returns for Bolt V2 & V3.
  """
  def test_spatial_and_temporal(port, _) do
    assert [
             #  success: %{"fields" => ["d"], "result_available_after" => _},
             success: %{"fields" => ["d"]},
             record: [[sig: 68, fields: [17167]]],
             #  success: %{"result_consumed_after" => _, "type" => "r"}
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN date('2017-01-01') as d")

    assert [
             success: %{"fields" => ["t"]},
             record: [[sig: 84, fields: [45_930_250_000_000, 3600]]],
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN time('12:45:30.25+01:00') AS t")

    assert [
             success: %{"fields" => ["t"]},
             record: [[sig: 116, fields: [45_930_250_000_000]]],
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN localtime('12:45:30.25') AS t")

    assert [
             success: %{"fields" => ["d"]},
             record: [[sig: 69, fields: [15, 34, 54, 5550]]],
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN duration('P1Y3M34DT54.00000555S') AS d")

    assert [
             success: %{"fields" => ["d"]},
             record: [[sig: 100, fields: [1_522_931_640, 543_000_000]]],
             success: %{"type" => "r"}
           ] =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN localdatetime('2018-04-05T12:34:00.543') AS d"
             )

    assert [
             success: %{"fields" => ["d"]},
             record: [[sig: 70, fields: [1_522_931_663, 543_000_000, 3600]]],
             success: %{"type" => "r"}
           ] =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN datetime('2018-04-05T12:34:23.543+01:00') AS d"
             )

    assert [
             success: %{"fields" => ["d"]},
             record: [[sig: 102, fields: [1_522_931_663, 543_000_000, "Europe/Berlin"]]],
             success: %{"type" => "r"}
           ] =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN datetime('2018-04-05T12:34:23.543[Europe/Berlin]') AS d"
             )

    assert [
             success: %{"fields" => ["p"]},
             record: [[sig: 88, fields: [7203, 40.0, 45.0]]],
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN point({x: 40, y: 45}) AS p")

    assert [
             success: %{"fields" => ["p"]},
             record: [[sig: 88, fields: [4326, 40.0, 45.0]]],
             success: %{"type" => "r"}
           ] =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN point({longitude: 40, latitude: 45}) AS p"
             )

    assert [
             success: %{"fields" => ["p"]},
             record: [[sig: 89, fields: [9157, 40.0, 45.0, 150.0]]],
             success: %{"type" => "r"}
           ] = Bolt.run_statement(:gen_tcp, port, "RETURN point({x: 40, y: 45, z: 150}) AS p")

    assert [
             success: %{"fields" => ["p"]},
             record: [[sig: 89, fields: [4979, 40.0, 45.0, 150.0]]],
             success: %{"type" => "r"}
           ] =
             Bolt.run_statement(
               :gen_tcp,
               port,
               "RETURN point({longitude: 40, latitude: 45, height: 150}) AS p"
             )
  end
end
