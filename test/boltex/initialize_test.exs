defmodule Boltex.InitializeTest do
  use ExUnit.Case

  alias Boltex.Bolt
  alias Boltex.UriHelper

  test "HANDSHAKE return version on success" do
    uri = UriHelper.get_info()
    port_opts = [active: false, mode: :binary, packet: :raw]
    {:ok, port} = :gen_tcp.connect(uri.host, uri.port, port_opts)

    assert {:ok, version} = Bolt.handshake(:gen_tcp, port)

    assert version in 1..3
  end

  test "HELLO works only in Bolt version >= 3" do
    uri = UriHelper.get_info()
    port_opts = [active: false, mode: :binary, packet: :raw]
    {:ok, port} = :gen_tcp.connect(uri.host, uri.port, port_opts)

    {:ok, version} = Bolt.handshake(:gen_tcp, port)

    res = Bolt.hello(:gen_tcp, port, uri.userinfo)

    if version >= 3 do
      assert {:ok, _} = res
    else
      assert {:error, _} = res
    end
  end

  test "INIT works only in Bolt version < 3" do
    uri = UriHelper.get_info()
    port_opts = [active: false, mode: :binary, packet: :raw]
    {:ok, port} = :gen_tcp.connect(uri.host, uri.port, port_opts)

    {:ok, version} = Bolt.handshake(:gen_tcp, port)

    res = Bolt.init(:gen_tcp, port, uri.userinfo)

    if version >= 3 do
      assert {:error, _} = res
    else
      assert {:ok, _} = res
    end
  end
end
