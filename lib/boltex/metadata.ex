defmodule Boltex.Metadata do
  defstruct [:bookmarks, :tx_timeout, :metadata]

  @type t :: %__MODULE__{
          bookmarks: [String.t()],
          tx_timeout: non_neg_integer(),
          metadata: map()
        }

  @spec new(map()) :: {:ok, Boltex.Metadata.t()} | {:error, String.t()}
  def new(data) do
    with {:ok, bookmarks} <- validate_bookmarks(Map.get(data, :bookmarks, [])),
         {:ok, tx_timeout} <- validate_timeout(Map.get(data, :tx_timeout)),
         {:ok, metadata} <- validate_metadata(Map.get(data, :metadata, %{})) do
      {:ok,
       %__MODULE__{
         bookmarks: bookmarks,
         tx_timeout: tx_timeout,
         metadata: metadata
       }}
    else
      error -> error
    end
  end

  @spec to_map(Boltex.Metadata.t()) :: map()
  def to_map(metadata) do
    metadata
    |> Map.from_struct()
    |> Enum.filter(fn {_, value} -> value != nil end)
    |> Enum.into(%{})
  end

  @spec validate_bookmarks(any()) :: {:ok, list()} | {:ok, nil} | {:error, String.t()}
  defp validate_bookmarks(bookmarks) when is_list(bookmarks) and length(bookmarks) > 0 do
    {:ok, bookmarks}
  end

  defp validate_bookmarks([]) do
    {:ok, nil}
  end

  defp validate_bookmarks(_) do
    {:error, "Invalid bookmkarks. Should be a list."}
  end

  @spec validate_timeout(any()) :: {:ok, integer()} | {:error, String.t()}
  defp validate_timeout(timeout) when (is_integer(timeout) and timeout > 0) or is_nil(timeout) do
    {:ok, timeout}
  end

  defp validate_timeout(_) do
    {:error, "Invalid timeout. Should be a positive integer."}
  end

  @spec validate_metadata(any()) :: {:ok, map()} | {:ok, nil} | {:error, String.t()}
  defp validate_metadata(metadata) when is_map(metadata) and map_size(metadata) > 0 do
    {:ok, metadata}
  end

  defp validate_metadata(%{}) do
    {:ok, nil}
  end

  defp validate_metadata(_) do
    {:error, "Invalid timeout. Should be a positive integer."}
  end
end
