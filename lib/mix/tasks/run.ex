defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Runs script or application on selected runtime"

  def run(args) do
    case args do
      [] -> run_app()
      _ -> run_script(Enum.join(args, " "))
    end
  end

  defp run_script(path) do
    :ssh.start()
    ash = Ash.basic_config(true)
    code = File.read!(path)
    Mix.shell().info("Running on: #{Ash.runtime_id(ash)}")
    Mix.shell().info("Running script: #{path}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "eval " <> code, Ash.toms())
    Ash.stdout(conn, chan)
  end

  defp run_app() do
    Mix.Task.run("ash.upload", ["keep"])
    ash = Ash.init()
    Mix.shell().info("Running on: #{Ash.runtime_id(ash)}")
    conn = Process.get(:ssh_conn)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "run", Ash.toms())
    Ash.stdout(conn, chan)
  end
end
