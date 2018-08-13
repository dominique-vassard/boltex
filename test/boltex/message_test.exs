defmodule Boltex.MessageTest do
  use ExUnit.Case, async: true

  alias Boltex.PackStream.Message

  describe "Encodes messages:" do
    test "ack_failure" do
      assert <<0x0, 0x2, 0xB0, 0xE, 0x0, 0x0>> = Message.encode({:ack_failure, []})
    end

    test "discard_all" do
      assert <<0x0, 0x2, 0xB0, 0x2F, 0x0, 0x0>> = Message.encode({:discard_all, []})
    end

    test "init" do
      assert <<0x0, 0x10, 0xB2, 0x1, _::binary>> = Message.encode({:init, []})

      assert <<0x0, 0x42, 0xB2, 0x1, _::binary>> =
               Message.encode({:init, [{"neo4j", "password"}]})
    end

    test "pull_all" do
      assert <<0x0, 0x2, 0xB0, 0x3F, 0x0, 0x0>> = Message.encode({:pull_all, []})
    end

    test "reset" do
      assert <<0x0, 0x2, 0xB0, 0xF, 0x0, 0x0>> = Message.encode({:reset, []})
    end

    test "run" do
      assert <<0x0, 0x13, 0xB2, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
               0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0x0,
               0x0>> = Message.encode({:run, ["RETURN 1 AS num"]})

      <<0x0, 0x1D, 0xB2, 0x10, 0xD0, 0x13, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x7B, 0x6E,
        0x75, 0x6D, 0x7D, 0x20, 0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA1, 0x83, 0x6E, 0x75, 0x6D,
        0x5, 0x0, 0x0>> = Message.encode({:run, ["RETURN {num} AS num", %{num: 5}]})
    end
  end

  test "Decodes message" do
    success_hex =
      <<0xB1, 0x70, 0xA1, 0x86, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x8B, 0x4E, 0x65, 0x6F, 0x34,
        0x6A, 0x2F, 0x33, 0x2E, 0x34, 0x2E, 0x31>>

    assert {:success, %{"server" => "Neo4j/3.4.1"}} = Message.decode(success_hex)

    failure_hex =
      <<0xB1, 0x7F, 0xA2, 0x84, 0x63, 0x6F, 0x64, 0x65, 0xD0, 0x25, 0x4E, 0x65, 0x6F, 0x2E, 0x43,
        0x6C, 0x69, 0x65, 0x6E, 0x74, 0x45, 0x72, 0x72, 0x6F, 0x72, 0x2E, 0x53, 0x65, 0x63, 0x75,
        0x72, 0x69, 0x74, 0x79, 0x2E, 0x55, 0x6E, 0x61, 0x75, 0x74, 0x68, 0x6F, 0x72, 0x69, 0x7A,
        0x65, 0x64, 0x87, 0x6D, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0xD0, 0x39, 0x54, 0x68, 0x65,
        0x20, 0x63, 0x6C, 0x69, 0x65, 0x6E, 0x74, 0x20, 0x69, 0x73, 0x20, 0x75, 0x6E, 0x61, 0x75,
        0x74, 0x68, 0x6F, 0x72, 0x69, 0x7A, 0x65, 0x64, 0x20, 0x64, 0x75, 0x65, 0x20, 0x74, 0x6F,
        0x20, 0x61, 0x75, 0x74, 0x68, 0x65, 0x6E, 0x74, 0x69, 0x63, 0x61, 0x74, 0x69, 0x6F, 0x6E,
        0x20, 0x66, 0x61, 0x69, 0x6C, 0x75, 0x72, 0x65, 0x2E>>

    failure =
      {:failure,
       %{
         "code" => "Neo.ClientError.Security.Unauthorized",
         "message" => "The client is unauthorized due to authentication failure."
       }}

    assert ^failure = Message.decode(failure_hex)
    assert {:record, [1]} = Message.decode(<<0xB1, 0x71, 0x91, 0x1>>)

    assert {:ignored, _} = Message.decode(<<0xB0, 0x7E>>)
  end
end
