defmodule BoltexTest do
  use ExUnit.Case

  alias Boltex.Bolt
  alias Boltex.UriHelper

  test "it works" do
    uri = UriHelper.get_info()
    Boltex.test(uri.host, uri.port, "RETURN 1 as num", %{}, uri.userinfo)
  end
end
