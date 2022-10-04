defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Runs application on selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload")
    ash = Ash.load_config()
    Mix.shell().info("Running on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "run", Ash.toms())
    Task.start_link(fn -> Ash.monitor(conn) end)
    Ash.stdout(conn, chan)
  end
end
