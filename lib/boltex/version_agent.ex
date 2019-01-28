defmodule Boltex.VersionAgent do
  @moduledoc """
  Since Bolt v3, `RUN` gets an additional parameter.
  Boltex user shouldn't be forced to store and pass protocol version to function,
  therefore we store it here
  """

  @doc """
  Start the agent with a default protocol version (version 1)
  """
  @spec start_link() :: {:error, any()} | {:ok, pid()}
  def start_link() do
    Agent.start_link(fn -> 1 end, name: __MODULE__)
  end

  @doc """
  Return the current protocol version
  """
  @spec get() :: integer()
  def get() do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Set the current protocol version
  """
  @spec set(integer()) :: :ok
  def set(version) do
    Agent.update(__MODULE__, fn _ -> version end)
  end
end
