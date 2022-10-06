defmodule Mix.Tasks.Ash.Eval do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Evaluate expression on app vm"

  def run(args) do
    :ssh.start()
    code = Enum.join(args, " ")
    ash = Ash.load_config()
    Mix.shell().info("Evaluating on: #{ash.name}@#{ash.runtime}")
    Mix.shell().info("Evaluating code: #{code}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "eval", Ash.toms())
    req = :erlang.term_to_binary(code)
    :ok = :ssh_connection.send(conn, chan, "apply " <> req, Ash.toms())

    receive do
      {:ssh_cm, _, {:data, _, _, data}} ->
        resp = :erlang.binary_to_term(data)
        IO.puts("#{inspect(resp)}")

      {:ssh_cm, _, {:eof, _}} ->
        :ok = :ssh_connection.close(conn, chan)
        :ok = :ssh.close(conn)
    end
  end
end
