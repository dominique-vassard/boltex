defmodule Boltex.EncoderCase do
  use ExUnit.CaseTemplate

  alias Boltex.Bolt
  alias Boltex.UriHelper

  setup do
    # Some encoding function required to know anout the ptoocol version used,
    # which is stored in the VersionAgent
    # The following code just open a connection to know which protocol version
    # to use and then close it
    uri = UriHelper.get_info()
    port_opts = [active: false, mode: :binary, packet: :raw]
    {:ok, port} = :gen_tcp.connect(uri.host, uri.port, port_opts)
    {:ok, bolt_version} = Bolt.handshake(:gen_tcp, port)
    :gen_tcp.close(port)

    {:ok, port: port, bolt_version: bolt_version}
  end
end
