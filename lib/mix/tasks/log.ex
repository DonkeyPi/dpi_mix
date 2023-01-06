defmodule Mix.Tasks.Dpi.Log do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Logs application on selected runtime"

  def run(_args) do
    :ssh.start()
    dpi = Dpi.basic_config(File.exists?("mix.exs"))
    Mix.shell().info("Logging from: #{Dpi.runtime_id(dpi)}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "log", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
