defmodule Mix.Tasks.Ash.Stop do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Stops application on selected runtime"

  def run(_args) do
    :ssh.start()
    ash = Ash.load_config()
    Mix.shell().info("Stopping on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "stop #{ash.bundle_name}", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
