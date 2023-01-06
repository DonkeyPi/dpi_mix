defmodule Mix.Tasks.Dpi.Install do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Installs application on selected runtime"

  def run(_args) do
    Mix.Task.run("dpi.upload", ["keep"])
    dpi = Dpi.init()
    Mix.shell().info("Installing on: #{Dpi.runtime_id(dpi)}")
    conn = Process.get(:ssh_conn)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "install", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
