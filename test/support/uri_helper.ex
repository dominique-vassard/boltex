defmodule Boltex.UriHelper do
  @doc """
  Return connection info extracted from uri
  """
  @spec get_info() :: map()
  def get_info do
    "bolt://neo4j:password@localhost:7687"
    |> URI.merge(System.get_env("NEO4J_TEST_URL") || "")
    |> URI.parse()
    |> Map.update!(:host, &String.to_charlist/1)
    |> Map.update!(:userinfo, fn
      nil ->
        {}

      userinfo ->
        userinfo
        |> String.split(":")
        |> List.to_tuple()
    end)
  end
end
