defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @toms 5_000
  @moms 2_000

  @shortdoc "Runs application against selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload")
    ash = Ash.load_config()
    Mix.shell().info("Running on runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, @toms)
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', @toms)
    :ok = :ssh_connection.send(conn, chan, "run #{ash.bundle_name}", @toms)
    Task.start_link(fn -> monitor(conn) end)
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

  # check the runtime is still alive
  defp monitor(conn) do
    :timer.sleep(@moms)
    {:ok, chan} = :ssh_connection.session_channel(conn, @toms)
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', @toms)
    :ok = :ssh_connection.send(conn, chan, "ping", @toms)

    receive do
      {:ssh_cm, _, {:data, _, _, "pong"}} -> :ok
      any -> raise "#{inspect(any)}"
    after
      @toms -> raise "Monitor timeout"
    end

    receive do
      {:ssh_cm, _, {:eof, _}} -> :ok
      any -> raise "#{inspect(any)}"
    end

    receive do
      {:ssh_cm, _, {:closed, _}} -> :ok
      any -> raise "#{inspect(any)}"
    end

    :ok = :ssh_connection.close(conn, chan)
    monitor(conn)
  end
end
