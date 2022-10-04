# mix run exs/iex.exs
# [x] arrow keys ^[[C^[[D^[[B^[[A
# [x] history
# [x] autocomplete elixir API
# [ ] autocomplete self
# [x] exit import
# [ ] single connection

case System.argv() do
  [] -> System.put_env("SSH_USER", "ash")
  [user] -> System.put_env("SSH_USER", user)
end

System.put_env("SSH_HOST", "localhost")

user = Process.whereis(:user)

updatable =
  :erlang.processes()
  |> Enum.filter(fn pid ->
    user ==
      Process.info(pid)
      |> Keyword.get(:group_leader)
  end)

wait_user = fn continue ->
  case Process.whereis(:user) do
    nil -> continue.(continue)
    user -> user
  end
end

defmodule Shell do
  def start() do
    spawn(&run/0)
  end

  def run() do
    :ok = :ssh.start()
    user = System.get_env("SSH_USER") |> String.to_charlist()
    host = System.get_env("SSH_HOST") |> String.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    pid = spawn_link(fn -> expander(host, user, opts) end)

    expand = fn code ->
      send(pid, {:expand, self(), code})

      receive do
        {:expand, ^pid, data} -> data
      end
    end

    :ok = Process.group_leader() |> :io.setopts(expand_fun: expand)
    :ssh.shell(host, 8022, opts)

    # *** ERROR: Shell process terminated! (^G to start new job) ***
    # Connection closed by peerStatus: 255
    System.halt()
  end

  def expander(host, user, opts) do
    {:ok, conn} = :ssh.connect(host, 8022, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, 2000)
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', 2000)
    :ok = :ssh_connection.send(conn, chan, "expand #{user}", 2000)
    loop(conn, chan, nil)
  end

  def loop(conn, chan, pid) do
    receive do
      {:expand, pid, code} ->
        code = :erlang.term_to_binary(code)
        :ok = :ssh_connection.send(conn, chan, "apply " <> code, 2000)
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
end

# fun("") -> {yes, "quit", []};
#     (_) -> {no, "", ["quit"]} end
# expand = fn
#   '' -> {:yes, 'exit', []}
#   _ -> {:no, '', ['exit']}
# end

:ok = Supervisor.terminate_child(:kernel_sup, :user)
_pid = :user_drv.start(['tty_sl -c -e', {Shell, :start, []}])
_user = wait_user.(wait_user)
# got an exception once
# ** (ArgumentError) argument error
#     :erlang.group_leader(#PID<0.9.0>, #PID<0.64.0>)
#     (elixir 1.13.4) lib/enum.ex:937: Enum."-each/2-lists^foreach/1-0-"/2
#     exs/ssh.exs:45: (file)
# Enum.each(updatable, fn pid -> :erlang.group_leader(pid, user) end)
System.no_halt(true)
