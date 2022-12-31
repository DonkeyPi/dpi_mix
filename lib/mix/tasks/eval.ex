defmodule Mix.Tasks.Ash.Eval do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Evaluate expression on app vm"

  def run(args) do
    :ssh.start()
    ash = Ash.basic_config(true)
    code = Enum.join(args, " ")
    Mix.shell().info("Evaluating on: #{Ash.runtime_id(ash)}")
    Mix.shell().info("Evaluating code: #{code}")
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
