defmodule Boltex.IntegrationCase do
  use ExUnit.CaseTemplate

  alias Boltex.Bolt
  alias Boltex.UriHelper

  setup do
    uri = UriHelper.get_info()
    port_opts = [active: false, mode: :binary, packet: :raw]
    {:ok, port} = :gen_tcp.connect(uri.host, uri.port, port_opts)
    {:ok, version} = Bolt.handshake(:gen_tcp, port)

    cond do
      version == 3 -> Bolt.hello(:gen_tcp, port, uri.userinfo)
      version < 3 -> Bolt.init(:gen_tcp, port, uri.userinfo)
    end

    on_exit(fn ->
      :gen_tcp.close(port)
    end)

    {:ok, port: port, bolt_version: version}
  end
end
