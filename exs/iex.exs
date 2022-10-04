# mix run exs/iex.exs
# [x] arrow keys ^[[C^[[D^[[B^[[A
# [x] history
# [x] autocomplete

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

:ok = Supervisor.terminate_child(:kernel_sup, :user)
_pid = :user_drv.start(['tty_sl -c -e', {IEx, :start, []}])
user = wait_user.(wait_user)
Enum.each(updatable, fn pid -> :erlang.group_leader(pid, user) end)
System.no_halt(true)
