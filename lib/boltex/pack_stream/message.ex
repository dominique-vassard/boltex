defmodule Boltex.PackStream.Message do
  @client_name "Boltex/0.4.0"

  @max_chunk_size 65_535
  @end_marker <<0x00, 0x00>>

  @ack_failure_signature 0x0E
  @discard_all_signature 0x2F
  @init_signature 0x01
  @pull_all_signature 0x3F
  @reset_signature 0x0F
  @run_signature 0x10

  @doc """
  Encode INIT message without auth token

  ## Example:
      iex> Message.encode(:init)
      <<0, 16, 178, 1, 140, 66, 111, 108, 116, 101, 120, 47, 48, 46, 52, 46, 48, 160,
        0, 0>>
  """
  def encode(:init) do
    encode(:init, {})
  end

  @doc """
  Encode all messages without data: ACK_FAILURE, DISCARD_ALL, PULL_ALL, RESET

  ## Examples:
      iex> Message.encode(:discard_all)
      <<0, 2, 176, 47, 0, 0>>
      iex> Message.encode(:ack_failure)
      <<0, 2, 176, 14, 0, 0>>
      iex> Message.encode(:discard_all)
      <<0, 2, 176, 47, 0, 0>>
      iex> Message.encode(:pull_all)
      <<0, 2, 176, 63, 0, 0>>
      iex> Message.encode(:reset)
      <<0, 2, 176, 15, 0, 0>>
  """
  def encode(message_type) when is_atom(message_type) do
    do_encode(message_type, [])
  end

  @doc """
  Encode INIT message with a valid auth token.
  The auth token is tuple formated as: {user, password}

  ## Example:
      iex(86)> Message.encode(:init, {"neo4j", "password"})
    <<0, 66, 178, 1, 140, 66, 111, 108, 116, 101, 120, 47, 48, 46, 52, 46, 48, 163,
      139, 99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 115, 136, 112, 97, 115,
      115, 119, 111, 114, 100, 137, 112, 114, 105, 110, 99, 105, 112, 97, 108, 133,
      ...>>
  """
  def encode(:init, auth) do
    do_encode(:init, [@client_name, auth_params(auth)])
  end

  @doc """
  Encode RUN message with its data: statement and parameters

  ## Example
      iex> Message.encode(:run, "RETURN 1 AS num")
      <<0, 19, 178, 16, 143, 82, 69, 84, 85, 82, 78, 32, 49, 32, 65, 83, 32, 110, 117,
      109, 160, 0, 0>>
      iex> Message.encode(:run, "RETURN {num} AS num", %{num: 1})
      <<0, 29, 178, 16, 208, 19, 82, 69, 84, 85, 82, 78, 32, 123, 110, 117, 109, 125,
        32, 65, 83, 32, 110, 117, 109, 161, 131, 110, 117, 109, 1, 0, 0>>

  """
  def encode(:run, statement, parameters \\ %{}) do
    do_encode(:run, [statement, parameters])
  end

  defp do_encode(message_type, data) do
    Boltex.Logger.log_message(:client, message_type, data)

    encoded =
      {signature(message_type), data}
      |> Boltex.PackStream.Encoder.encode()
      |> generate_chunks()

    Boltex.Logger.log_message(:client, message_type, encoded, :hex)
    encoded
  end

  defp auth_params({}), do: %{}

  defp auth_params({username, password}) do
    %{
      scheme: "basic",
      principal: username,
      credentials: password
    }
  end

  defp signature(:ack_failure), do: @ack_failure_signature
  defp signature(:discard_all), do: @discard_all_signature
  defp signature(:init), do: @init_signature
  defp signature(:pull_all), do: @pull_all_signature
  defp signature(:reset), do: @reset_signature
  defp signature(:run), do: @run_signature

  defp(generate_chunks(data, chunks \\ []))

  defp generate_chunks(data, chunks) when byte_size(data) > @max_chunk_size do
    <<chunk::binary-@max_chunk_size, rest::binary>> = data
    generate_chunks(rest, [format_chunk(chunk) | chunks])
  end

  defp generate_chunks(<<>>, chunks) do
    [@end_marker | chunks]
    |> Enum.reverse()
    |> Enum.join()
  end

  defp generate_chunks(data, chunks) do
    generate_chunks(<<>>, [format_chunk(data) | chunks])
  end

  defp format_chunk(chunk) do
    <<byte_size(chunk)::16>> <> chunk
  end
end