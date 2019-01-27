defmodule Boltex.VersionAgent do
  @moduledoc """
  Since Bolt v3, `RUN` gets an additional parameter.
  Boltex user shouldn't be forced to store and pass protocol version to function,
  therefore we store it here
  """
  use Agent

  @doc """
  Start the agent with current protocol version
  """
  @spec start_link(integer()) :: {:error, any()} | {:ok, pid()}
  def start_link(version) do
    Agent.start_link(fn -> version end, name: __MODULE__)
  end

  @doc """
  Return the current protocol version
  """
  @spec get() :: integer()
  def get() do
    Agent.get(__MODULE__, & &1)
  end
end
