defmodule Mix.Tasks.Ash.Shell do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Connect to app shell"

  # worked out at exs/ssh.exs
  # https://github.com/rebar/rebar/blob/master/src/rebar_shell.erl
  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Connecting to app shell: #{Ash.runtime_id(ash)}")
    Mix.shell().info("ssh -p#{ash.port} #{ash.name}@#{ash.host}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    args = [host, ash.port, opts]
    :ok = Supervisor.terminate_child(:kernel_sup, :user)
    _pid = :user_drv.start(['tty_sl -c -e', {__MODULE__, :start_shell, args}])
    _user = wait_user()
    System.no_halt(true)
  end

  def start_shell(host, port, opts) do
    spawn(fn -> run_shell(host, port, opts) end)
  end

  defp run_shell(host, port, opts) do
    :ok = :ssh.start()
    {:ok, conn} = :ssh.connect(host, port, opts)
    pid = spawn_link(fn -> expander(conn) end)

    expand = fn code ->
      send(pid, {:expand, self(), code})

      receive do
        {:expand, ^pid, data} -> data
      after
        4000 -> raise "expand timeout"
      end
    end

    :ok = Process.group_leader() |> :io.setopts(expand_fun: expand)
    :ssh.shell(conn)
    System.halt()
  end

  defp expander(conn) do
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "expand", Ash.toms())
    loop(conn, chan, nil)
  end

  defp loop(conn, chan, pid) do
    receive do
      {:expand, pid, code} ->
        code = :erlang.term_to_binary(code)
        :ok = :ssh_connection.send(conn, chan, "apply " <> code, Ash.toms())
        loop(conn, chan, pid)

      {:ssh_cm, _, {:data, _, _, data}} ->
        data = :erlang.binary_to_term(data)
        send(pid, {:expand, self(), data})
        loop(conn, chan, nil)

      {:ssh_cm, _, {:eof, _}} ->
        :ok = :ssh_connection.close(conn, chan)
        :ok = :ssh.close(conn)
        raise "connection closed"
    end
  end

  defp wait_user() do
    case Process.whereis(:user) do
      nil -> wait_user()
      user -> user
    end
  end
end
