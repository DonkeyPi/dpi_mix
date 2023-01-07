defmodule Mix.Tasks.Dpi.Shell do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Connect to app shell"

  # worked out at exs/ssh.exs
  # https://github.com/rebar/rebar/blob/master/src/rebar_shell.erl
  def run(args) do
    {with_app, type, rt} =
      case {args, File.exists?("mix.exs")} do
        {["runtime"], _} -> {false, "runtime", nil}
        {[runtime], _} -> {false, "runtime", runtime}
        {[], true} -> {true, "app", nil}
        {_, false} -> {false, "runtime", nil}
      end

    dpi = Dpi.basic_config(with_app)

    dpi =
      if rt != nil do
        rt = rt |> String.to_atom()

        unless Map.has_key?(dpi.runtimes, rt) do
          Mix.raise("Runtime #{rt} not found in #{dpi.dpi_mix_exs_p}")
        end

        rtc = dpi.runtimes[rt] |> Dpi.rt_defaults()
        %{dpi | port: rtc[:port], host: rtc[:host], runtime: rt, runtime_entry: rtc}
      else
        dpi
      end

    Mix.shell().info("Connecting to #{type} shell: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("ssh -p#{dpi.port} #{dpi.name}@#{dpi.host}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    args = [host, dpi.port, opts]
    :ok = Supervisor.terminate_child(:kernel_sup, :user)
    _pid = :user_drv.start(['tty_sl -c -e', {__MODULE__, :start_shell, args}])
    _user = wait_user()
    System.no_halt(true)
  end

  # ["nerves"] -> {:std_shell, 22, 'dpi'}
  # wont autocomplete
  # left as reference
  # nerves not always available
  # everything should be doable from runtime
  # def std_shell(host, port, opts) do
  #   spawn(fn ->
  #     :ok = :ssh.start()
  #     :ok = :ssh.shell(host, port, opts)
  #     System.halt()
  #   end)
  # end

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
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "expand", Dpi.toms())
    loop(conn, chan, nil)
  end

  defp loop(conn, chan, pid) do
    receive do
      {:expand, pid, code} ->
        code = :erlang.term_to_binary(code)
        :ok = :ssh_connection.send(conn, chan, "apply " <> code, Dpi.toms())
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
