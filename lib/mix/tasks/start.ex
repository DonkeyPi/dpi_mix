defmodule Mix.Tasks.Ash.Start do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Starts application on selected runtime"

  def run(_args) do
    :ssh.start()
    ash = Ash.load_config()
    Mix.shell().info("Starting on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "start #{ash.bundle_name}", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
