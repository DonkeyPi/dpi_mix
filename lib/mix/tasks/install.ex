defmodule Mix.Tasks.Ash.Install do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Installs application on selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload", ["keep"])
    ash = Ash.get_config()
    Mix.shell().info("Installing on: #{Ash.runtime_id(ash)}")
    conn = Process.get(:ssh_conn)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "install", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
