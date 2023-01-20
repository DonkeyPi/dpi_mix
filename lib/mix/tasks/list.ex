defmodule Mix.Tasks.Dpi.List do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "List applications on selected runtime"

  def run(_args) do
    :ssh.start()
    dpi = Dpi.basic_config(false)
    Mix.shell().info("Listing from: #{Dpi.runtime_id(dpi)}")
    host = dpi.host |> String.to_charlist()
    opts = [silently_accept_hosts: true] |> Dpi.add_user_dir()
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "list", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
