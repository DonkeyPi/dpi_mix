defmodule Mix.Tasks.Ash.Start do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Starts application on selected runtime"

  def run(_args) do
    :ssh.start()
    ash = Ash.get_config()
    Mix.shell().info("Starting on: #{Ash.runtime_id(ash)}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "start", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
