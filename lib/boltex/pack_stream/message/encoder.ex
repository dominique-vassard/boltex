defmodule Boltex.PackStream.Message.Encoder do
  @moduledoc false

  # Manages the message encoding.

  # A mesage is a tuple formated as:
  # `{message_type, data}`
  # with:
  #   - message_type: atom amongst the valid message type (:init, :discard_all, :pull_all, :ack_failure, :reset, :run)
  #   - data: a list of data to be used by the message

  @client_name "Boltex/0.5.0"

  @max_chunk_size 65_535
  @end_marker <<0x00, 0x00>>

  @ack_failure_signature 0x0E
  @begin_signature 0x11
  @commit_signature 0x12
  @discard_all_signature 0x2F
  @hello_signature 0x01
  @init_signature 0x01
  @pull_all_signature 0x3F
  @reset_signature 0x0F
  @rollback_signature 0x13
  @run_signature 0x10

  @doc """
  Encode INIT message without auth token

  ## Example:
      iex> Message.encode({:init, []})
      <<0, 16, 178, 1, 140, 66, 111, 108, 116, 101, 120, 47, 48, 46, 52, 46, 48, 160,
        0, 0>>
  """
  @spec encode({Boltex.PackStream.Message.out_signature(), list()}) ::
          Boltex.PackStream.Message.encoded()
  def encode({:init, []}) do
    encode({:init, [{}]})
  end

  @doc """
  Encode INIT message with a valid auth token.
  The auth token is tuple formated as: {user, password}

  ## Example:
      iex(86)> Message.encode({:init, [{"neo4j", "password"}]})
    <<0, 66, 178, 1, 140, 66, 111, 108, 116, 101, 120, 47, 48, 46, 52, 46, 48, 163,
      139, 99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 115, 136, 112, 97, 115,
      115, 119, 111, 114, 100, 137, 112, 114, 105, 110, 99, 105, 112, 97, 108, 133,
      ...>>
  """
  def encode({:init, [auth]}) do
    do_encode(:init, [@client_name, auth_params(auth)])
  end

  @doc """
  Encode HELLO message without auth token;

  HELLO message is similar to INIT but is used by Bolt protocol v3 and higher

  ## Example:
      iex(1)> Message.encode({:hello, [{"neo4j", "password"}]})
      <<0, 77, 177, 1, 164, 139, 99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 115,
      136, 112, 97, 115, 115, 119, 111, 114, 100, 137, 112, 114, 105, 110, 99, 105,
      112, 97, 108, 133, 110, 101, 111, 52, 106, 134, 115, 99, 104, 101, 109, 101,
      133, ...>>
  """
  def encode({:hello, []}) do
    encode({:hello, [{}]})
  end

  @doc """
  Encode HELLO message with auth token

  HELLO message is similar to INIT but is used by Bolt protocol v3 and higher

  ## Example:
      iex> Message.encode({:hello, []})
      <<0, 27, 177, 1, 161, 138, 117, 115, 101, 114, 95, 97, 103, 101, 110, 116, 140,
      66, 111, 108, 116, 101, 120, 47, 48, 46, 53, 46, 48, 0, 0>>
  """
  def encode({:hello, [auth]}) do
    params =
      auth
      |> auth_params()
      |> Map.put(:user_agent, @client_name)

    do_encode(:hello, [params])
  end

  @doc """
  Encode BEGIN message without metadata.

  COMMIT is used to open a transaction
  """
  def encode({:begin, []}) do
    encode({:begin, [%{}]})
  end

  @doc """
  Encode BEGIN message with metadata
  """
  def encode({:begin, [%Boltex.Metadata{} = metadata]}) do
    encode({:begin, [Boltex.Metadata.to_map(metadata)]})
  end

  @doc """
  Encode RUN message with its data: statement and parameters

  RUN takes only 2 parameters in V2:
  - the statement to execute
  - the statement binds

  RUN takes 3 parameters in V3:
  - the statement to execute
  - the statement binds
  - metadata

  ## Example
      iex> Message.encode({:run, ["RETURN 1 AS num"]})
      <<0, 19, 178, 16, 143, 82, 69, 84, 85, 82, 78, 32, 49, 32, 65, 83, 32, 110, 117,
      109, 160, 0, 0>>
      iex> Message.encode({:run, ["RETURN {num} AS num", %{num: 1}]})
      <<0, 29, 178, 16, 208, 19, 82, 69, 84, 85, 82, 78, 32, 123, 110, 117, 109, 125,
        32, 65, 83, 32, 110, 117, 109, 161, 131, 110, 117, 109, 1, 0, 0>>

  """

  def encode({:run, [_statement]} = message) do
    encode_run(message, Boltex.VersionAgent.get())
  end

  def encode({:run, [_statment, _params]} = message) do
    encode_run(message, Boltex.VersionAgent.get())
  end

  @doc """
  Encode all messages without data: ACK_FAILURE, DISCARD_ALL, PULL_ALL, RESET

  ## Examples:
      iex> Message.encode({:discard_all, []})
      <<0, 2, 176, 47, 0, 0>>
      iex> Message.encode({:ack_failure, []})
      <<0, 2, 176, 14, 0, 0>>
      iex> Message.encode({:pull_all, []})
      <<0, 2, 176, 63, 0, 0>>
      iex> Message.encode({:reset, []})
      <<0, 2, 176, 15, 0, 0>>
  """
  def encode({message_type, data}) do
    do_encode(message_type, data)
  end

  @spec encode_run({Boltex.PackStream.Message.out_signature(), list()}, integer()) ::
          Boltex.PackStream.Message.encoded()
  defp encode_run({:run, [statement]}, bolt_version) when bolt_version <= 2 do
    do_encode(:run, [statement, %{}])
  end

  defp encode_run({:run, [statement]}, _) do
    do_encode(:run, [statement, %{}, %{}])
  end

  defp encode_run({:run, [statement, params]}, bolt_version) when bolt_version <= 2 do
    do_encode(:run, [statement, params])
  end

  defp encode_run({:run, [statement, params]}, _) do
    do_encode(:run, [statement, params, %{}])
  end

  @spec do_encode(Boltex.PackStream.Message.out_signature(), list()) ::
          Boltex.PackStream.Message.encoded()
  defp do_encode(message_type, data) do
    Boltex.Logger.log_message(:client, message_type, data)

    encoded =
      {signature(message_type), data}
      |> Boltex.PackStream.Encoder.encode()
      |> generate_chunks()

    Boltex.Logger.log_message(:client, message_type, encoded, :hex)
    encoded
  end

  @spec auth_params({} | {String.t(), String.t()}) :: map()
  defp auth_params({}), do: %{}

  defp auth_params({username, password}) do
    %{
      scheme: "basic",
      principal: username,
      credentials: password
    }
  end

  @spec signature(Boltex.PackStream.Message.out_signature()) :: integer()
  defp signature(:ack_failure), do: @ack_failure_signature
  defp signature(:begin), do: @begin_signature
  defp signature(:commit), do: @commit_signature
  defp signature(:discard_all), do: @discard_all_signature
  defp signature(:hello), do: @hello_signature
  defp signature(:init), do: @init_signature
  defp signature(:pull_all), do: @pull_all_signature
  defp signature(:reset), do: @reset_signature
  defp signature(:rollback), do: @rollback_signature
  defp signature(:run), do: @run_signature

  @spec generate_chunks(Boltex.PackStream.value() | <<>>, list()) ::
          Boltex.PackStream.Message.encoded()
  defp generate_chunks(data, chunks \\ [])

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

  @spec format_chunk(Boltex.PackStream.value()) :: Boltex.PackStream.Message.encoded()
  defp format_chunk(chunk) do
    <<byte_size(chunk)::16>> <> chunk
  end
end
