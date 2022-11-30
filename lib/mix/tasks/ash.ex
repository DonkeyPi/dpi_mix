defmodule Mix.Tasks.Ash do
  use Mix.Task

  @default_port 8022
  @runs_folder "/ash_runs"
  # ~/.ash_runtime is runtime folder
  @runtime_file ".ash_runtime.sel"
  @runtime_list ".ash_runtime.exs"

  # global timeout
  @toms 5_000

  # initial monitor delay
  @moms 2_000

  def toms(), do: @toms
  def runtime_file(), do: @runtime_file
  def find_runtime(), do: find_path(@runtime_file, @runtime_file)

  def run(_args) do
    ash = get_config()
    Mix.shell().info("Selected runtime: #{runtime_id(ash)}")
    Mix.shell().info("Runtime file: #{ash.runtime_path}")
    Mix.shell().info("Bundle path: #{ash.bundle_path}")
    Mix.shell().info("Config map: #{inspect(ash)}")
  end

  def runtime_id(ash) do
    "#{inspect({ash.runtime, ash.runtime_entry})}"
  end

  def find_path(initial, current) do
    case File.regular?(current) do
      true ->
        current |> Path.expand()

      false ->
        next = Path.join("..", current)
        next_d = Path.expand(next) |> Path.dirname()
        curr_d = Path.expand(current) |> Path.dirname()

        case curr_d != next_d do
          true -> find_path(initial, next)
          _ -> initial
        end
    end
  end

  def get_config() do
    if Process.whereis(__MODULE__) == nil do
      config = load_config()
      Agent.start_link(fn -> config end, name: __MODULE__)
    end

    Agent.get(__MODULE__, fn config -> config end)
  end

  def load_config() do
    runtime_list = find_path(@runtime_list, @runtime_list)
    runtime_file = find_path(@runtime_file, @runtime_file)

    unless File.exists?(runtime_file) do
      Mix.raise("Runtime not selected, use: mix ash.runtime <runtime>")
    end

    unless File.exists?(runtime_list) do
      Mix.raise("Runtime not configured, create file #{@runtime_list}")
    end

    rt =
      runtime_file
      |> File.read!()
      |> String.trim()

    rts =
      runtime_list
      |> Code.eval_file()
      |> elem(0)
      |> Enum.map(fn {k, v} -> {"#{k}", v} end)
      |> Enum.into(%{})

    unless Map.has_key?(rts, rt) do
      Mix.raise("Runtime #{rt} not found in #{runtime_list}")
    end

    rtc = Map.fetch!(rts, rt)
    host = Keyword.fetch!(rtc, :host)
    port = Keyword.get(rtc, :port, @default_port)
    target = Keyword.get(rtc, :target, :host)

    # override environment
    if Mix.target() != target do
      System.put_env("MIX_TARGET", "#{target}")
      Mix.target(target)
    end

    # All it does is to append aliases to core mix tasks.
    # Nerves.Bootstrap.Aliases.init could be called directly
    # as that is all the application does on init but
    # nerves checks for the app to be running later on.
    :ok = Application.ensure_started(:nerves_bootstrap)

    pc = Mix.Project.config()
    deps = get_deps(pc)
    name = pc |> Keyword.fetch!(:app)
    version = pc |> Keyword.fetch!(:version)

    build_path = Mix.Project.build_path()

    bundle_name =
      pc
      |> Keyword.fetch!(:app)
      |> Atom.to_string()
      |> String.replace_suffix("", ".tgz")

    bundle_path =
      build_path
      |> Path.join(bundle_name)

    %{
      name: name,
      deps: deps,
      version: version,
      target: target,
      host: host,
      port: port,
      runtime: rt,
      build_path: build_path,
      runs_folder: @runs_folder,
      runtime_entry: rts[rt],
      runtime_file: @runtime_file,
      runtime_path: runtime_file,
      runtimes_file: @runtime_list,
      runtimes_path: runtime_list,
      bundle_name: bundle_name,
      bundle_path: bundle_path
    }
  end

  defp exit_on_enter(conn) do
    spawn_link(fn ->
      IO.gets("")
      cleanup(conn)
    end)
  end

  defp exit_on_ping(conn) do
    spawn_link(fn -> monitor(conn) end)
  end

  def stdout(conn, chan) do
    exit_on_enter(conn)
    exit_on_ping(conn)
    stdout_loop(conn, chan)
  end

  defp stdout_loop(conn, chan) do
    receive do
      {:ssh_cm, _, {:data, _, _, data}} ->
        IO.binwrite(data)
        stdout_loop(conn, chan)

      {:ssh_cm, _, {:eof, _}} ->
        cleanup(conn)

      {:ssh_cm, _, {:closed, _}} ->
        cleanup(conn)
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
    after
      @toms -> raise "Monitor timeout"
    end

    receive do
      {:ssh_cm, _, {:closed, _}} -> :ok
      any -> raise "#{inspect(any)}"
    after
      @toms -> raise "Monitor timeout"
    end

    :ok = :ssh_connection.close(conn, chan)
    monitor(conn)
  end

  defp cleanup(conn) do
    :ssh.close(conn)
    System.halt()
  end

  defp get_deps(pc) do
    pc
    |> runtime_deps()
    |> recurse_deps([])
    |> Enum.map(fn {name, _} -> name end)
  end

  defp runtime_deps(pc) do
    pc
    |> Keyword.fetch!(:deps)
    |> Enum.filter(fn
      {_n, v} when is_binary(v) -> true
      {_n, p} when is_list(p) -> Keyword.get(p, :runtime, true)
      {_n, _v, p} when is_list(p) -> Keyword.get(p, :runtime, true)
    end)
    |> Enum.map(fn
      {n, p} -> {n, {p}}
      {n, v, p} -> {n, {v, p}}
    end)
  end

  defp recurse_deps([], acc), do: acc

  defp recurse_deps([{name, props} | tail], acc) do
    path = get_proj_path(name, props)

    acc =
      Mix.Project.in_project(name, path, fn _module ->
        Mix.Project.config()
        |> runtime_deps()
        |> recurse_deps([])
      end) ++ acc

    recurse_deps(tail, [{name, props} | acc])
  end

  defp get_proj_path(name, props) do
    path =
      Mix.Project.deps_path()
      |> Path.join("#{name}")

    case File.dir?(path) do
      true ->
        path

      _ ->
        case props do
          {p} -> Keyword.fetch!(p, :path)
          {_, p} -> Keyword.fetch!(p, :path)
        end
    end
  end
end
