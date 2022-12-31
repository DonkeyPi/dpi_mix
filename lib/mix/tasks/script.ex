defmodule Mix.Tasks.Ash.Script do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Evaluate script on app vm"

  def run(args) do
    :ssh.start()
    ash = Ash.basic_config(true)
    path = Enum.join(args, " ")
    code = File.read!(path)
    Mix.shell().info("Evaluating on: #{Ash.runtime_id(ash)}")
    Mix.shell().info("Evaluating script: #{path}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "eval " <> code, Ash.toms())
    Ash.stdout(conn, chan)
  end
end
