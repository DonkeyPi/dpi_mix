defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Runs application against selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload")
    ash = Ash.load_config()
    Mix.shell().info("Running on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    {:ok, conn} = :ssh.connect(host, ash.port, [])
    {:ok, chan} = :ssh_connection.session_channel(conn, 2000)
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', 2000)
    :ok = :ssh_connection.send(conn, chan, "run #{ash.escript_name}", 2000)
    receive_msg(conn, chan)
  end

  defp receive_msg(conn, chan) do
    receive do
      {:ssh_cm, _, {:data, _, _, data}} ->
        IO.binwrite(data)
        receive_msg(conn, chan)

      {:ssh_cm, _, {:eof, _}} ->
        :ok = :ssh_connection.close(conn, chan)
        :ok = :ssh.close(conn)
    end
  end
end
