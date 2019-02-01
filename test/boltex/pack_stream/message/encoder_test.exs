defmodule Boltex.PackStream.Message.EncoderTest do
  use ExUnit.Case, async: true
  alias Boltex.PackStream.Message.Encoder

  defmodule TestUser do
    defstruct name: "", bolt_sips: true
  end

  test "ack_failure" do
    assert <<0x0, 0x2, 0xB0, 0xE, 0x0, 0x0>> = Encoder.encode({:ack_failure, []})
  end

  test "discard_all" do
    assert <<0x0, 0x2, 0xB0, 0x2F, 0x0, 0x0>> = Encoder.encode({:discard_all, []})
  end

  test "init" do
    assert <<0x0, 0x10, 0xB2, 0x1, _::binary>> = Encoder.encode({:init, []})

    assert <<0x0, 0x42, 0xB2, 0x1, _::binary>> = Encoder.encode({:init, [{"neo4j", "password"}]})
  end

  test "pull_all" do
    assert <<0x0, 0x2, 0xB0, 0x3F, 0x0, 0x0>> = Encoder.encode({:pull_all, []})
  end

  test "reset" do
    assert <<0x0, 0x2, 0xB0, 0xF, 0x0, 0x0>> = Encoder.encode({:reset, []})
  end

  test "run" do
    assert <<0x0, 0x13, 0xB2, 0x10, 0x8F, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x31, 0x20,
             0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA0, 0x0,
             0x0>> = Encoder.encode({:run, ["RETURN 1 AS num"]})

    assert <<0x0, 0x1D, 0xB2, 0x10, 0xD0, 0x13, 0x52, 0x45, 0x54, 0x55, 0x52, 0x4E, 0x20, 0x7B,
             0x6E, 0x75, 0x6D, 0x7D, 0x20, 0x41, 0x53, 0x20, 0x6E, 0x75, 0x6D, 0xA1, 0x83, 0x6E,
             0x75, 0x6D, 0x5, 0x0,
             0x0>> = Encoder.encode({:run, ["RETURN {num} AS num", %{num: 5}]})
  end

  test "bug fix: encoding struct fails" do
    query = "CREATE (n:User {props})"
    params = %{props: %TestUser{bolt_sips: true, name: "Strut"}}

    assert <<0x0, 0x39, 0xB2, 0x10, 0xD0, 0x17, 0x43, 0x52, 0x45, 0x41, 0x54, 0x45, 0x20, 0x28,
             0x6E, 0x3A, 0x55, 0x73, 0x65, 0x72, 0x20, 0x7B, 0x70, 0x72, 0x6F, 0x70, 0x73, 0x7D,
             0x29, 0xA1, 0x85, 0x70, 0x72, 0x6F, 0x70, 0x73, 0xA2, 0x89, 0x62, 0x6F, 0x6C, 0x74,
             0x5F, 0x73, 0x69, 0x70, 0x73, 0xC3, 0x84,
             _::binary>> = Encoder.encode({:run, [query, params]})
  end
end
