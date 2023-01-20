defmodule Mix.Tasks.Dpi.Eval do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Evaluate expression on app vm"

  def run(args) do
    :ssh.start()
    dpi = Dpi.basic_config(true)
    code = Enum.join(args, " ")
    Mix.shell().info("Evaluating on: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("Evaluating code: #{code}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "eval " <> code, Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
