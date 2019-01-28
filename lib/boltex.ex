defmodule Boltex do
  # Elixir library for using the Neo4J Bolt Protocol.
  #
  # It supports de- and encoding of Boltex binaries and sending and receiving
  # of data using the Bolt protocol.
  use Application
  alias Boltex.Bolt

  # def start_link(opts) do
  #   Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  # end

  # @impl true
  # def init(_args) do
  #   children = [
  #     Boltex.VersionAgent
  #   ]

  #   Supervisor.init(children, strategy: :one_for_one)
  # end

  def start(_type, _args) do
    children = [
      {Boltex.VersionAgent, []}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  @doc """
  A simple function to test the library

  ## Example

      iex> Boltex.test('localhost', 7687, "RETURN 1 as num", %{}, {"neo4j", "password"})
      [
        success: %{"fields" => ["num"], "result_available_after" => 1},
        record: [1],
        success: %{"result_consumed_after" => 0, "type" => "r"}
      ]

  """
  @spec test(charlist(), integer(), String.t(), map(), tuple()) :: list() | Boltex.Error.t()
  def test(host, port, query, params \\ %{}, auth \\ {}) do
    {:ok, p} = :gen_tcp.connect(host, port, active: false, mode: :binary, packet: :raw)

    {:ok, version} = Bolt.handshake(:gen_tcp, p)

    case version do
      3 ->
        {:ok, _info} = Bolt.hello(:gen_tcp, p, auth)

      _ ->
        {:ok, _info} = Bolt.init(:gen_tcp, p, auth)
    end

    Bolt.run_statement(:gen_tcp, p, query, params)
  end
end
