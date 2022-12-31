defmodule Mix.Tasks.Ash.List do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "List applications on selected runtime"

  def run(_args) do
    :ssh.start()
    ash = Ash.basic_config(false)
    Mix.shell().info("Listing from: #{Ash.runtime_id(ash)}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "list", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
