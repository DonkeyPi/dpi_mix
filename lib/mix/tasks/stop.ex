defmodule Mix.Tasks.Dpi.Stop do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Stops application on selected runtime"

  def run(_args) do
    :ssh.start()
    dpi = Dpi.init()
    Mix.shell().info("Stopping on: #{Dpi.runtime_id(dpi)}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "stop", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
