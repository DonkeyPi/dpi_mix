defmodule Mix.Tasks.Dpi.Run do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Runs script or application on selected runtime"

  def run(args) do
    case args do
      [] -> run_app()
      _ -> run_script(File.exists?("mix.exs"), Enum.join(args, " "))
    end
  end

  defp run_script(with_app, path) do
    :ssh.start()
    dpi = Dpi.basic_config(with_app)
    code = File.read!(path)
    Mix.shell().info("Running on: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("Running script: #{path}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "eval " <> code, Dpi.toms())
    Dpi.stdout(conn, chan)
  end

  defp run_app() do
    Mix.Task.run("dpi.upload", ["keep"])
    dpi = Dpi.init()
    Mix.shell().info("Running on: #{Dpi.runtime_id(dpi)}")
    conn = Process.get(:ssh_conn)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "run", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
