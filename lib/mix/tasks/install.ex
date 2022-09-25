defmodule Mix.Tasks.Ash.Install do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Installs application on selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload")
    ash = Ash.load_config()
    Mix.shell().info("Installing on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "install #{ash.name}", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
