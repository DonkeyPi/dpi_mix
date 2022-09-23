defmodule Mix.Tasks.Ash.Shell do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Retrieves runtime cookie"

  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Querying runtime: #{ash.runtime}")
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    :ok = :ssh.start()
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "cookie", Ash.toms())

    cookie =
      receive do
        {:ssh_cm, _, {:data, _, _, cookie}} -> cookie
        any -> raise "#{inspect(any)}"
      after
        Ash.toms() -> raise "Monitor timeout"
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
    :ok = :ssh.close(conn)
    File.write!(ash.cookie_path, cookie)

    user = System.fetch_env!("USER")
    {:ok, hostname} = :inet.gethostname()
    local_node = inspect("#{user}@#{hostname}")
    rem_node = inspect("#{ash.name}@#{host}")
    cookie = inspect(cookie)
    args = ["--sname", local_node, "--cookie", cookie, "--remsh", rem_node]
    Mix.shell().info("iex #{Enum.join(args, " ")}")
    args = ["--sname", local_node, "--cookie", "`cat #{ash.cookie_path}`", "--remsh", rem_node]
    Mix.shell().info("iex #{Enum.join(args, " ")}")
  end
end
