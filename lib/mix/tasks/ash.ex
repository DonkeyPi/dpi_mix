defmodule Mix.Tasks.Ash do
  use Mix.Task

  @default_port 8022
  @runs_folder "/ash_runs"
  # ~/.ash_runtime is runtime folder
  @ash_mix_srt ".ash_mix.srt"
  @ash_mix_exs ".ash_mix.exs"

  # global timeout
  @toms 5_000

  # initial monitor delay
  @moms 2_000

  def toms(), do: @toms
  def ash_mix_srt(), do: @ash_mix_srt
  def find_ash_mix_srt(), do: find_path(@ash_mix_srt, @ash_mix_srt)

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
    ash_mix_exs = find_path(@ash_mix_exs, @ash_mix_exs)
    ash_mix_srt = find_path(@ash_mix_srt, @ash_mix_srt)

    unless File.exists?(ash_mix_srt) do
      Mix.raise("Runtime not selected, use: mix ash.runtime <runtime>")
    end

    unless File.exists?(ash_mix_exs) do
      Mix.raise("Runtime not configured, create file #{@ash_mix_exs}")
    end

    rt =
      ash_mix_srt
      |> File.read!()
      |> String.trim()
      |> String.to_atom()

    mix_ex =
      ash_mix_exs
      |> Code.eval_file()
      |> elem(0)

    nerves_deps = mix_ex |> Keyword.get(:nerves_deps, [])

    rts =
      mix_ex
      |> Keyword.get(:ash_runtimes, [])
      |> Enum.into(%{})

    unless Map.has_key?(rts, rt) do
      Mix.raise("Runtime #{rt} not found in #{ash_mix_exs}")
    end

    rtc = Map.fetch!(rts, rt)
    host = Keyword.fetch!(rtc, :host)
    port = Keyword.get(rtc, :port, @default_port)
    target = Keyword.get(rtc, :target, :host)

    # override target and reload config/config.exs
    if Mix.target() != target do
      System.put_env("MIX_TARGET", "#{target}")
      Mix.target(target)
      Mix.Tasks.Loadconfig.run([])
    end

    update_config(nerves_deps)

    # firmware project auto start it in config/config.ex
    Application.stop(:nerves_bootstrap)

    # All it does is to append aliases to core mix tasks.
    # Nerves.Bootstrap.Aliases.init could be called directly
    # as that is all the application does on init but
    # nerves checks for the app to be running later on.
    :ok = Application.ensure_started(:nerves_bootstrap)

    pc = Mix.Project.config()
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
      version: version,
      target: target,
      host: host,
      port: port,
      runtime: rt,
      build_path: build_path,
      runs_folder: @runs_folder,
      runtime_entry: rts[rt],
      ash_mix_srt: @ash_mix_srt,
      runtime_path: ash_mix_srt,
      runtimes_file: @ash_mix_exs,
      runtimes_path: ash_mix_exs,
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

  def get_deps(pc) do
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
        # deps with format {name, version}
        # should not get here after deps.get
        case props do
          {_, p} -> Keyword.get(p, :path)
          {p} -> Keyword.get(p, :path)
        end
    end
  end

  defp defs_map(deps) do
    for dep <- deps, into: %{} do
      case dep do
        {n, vp} -> {n, {n, vp}}
        {n, v, p} -> {n, {n, v, p}}
      end
    end
  end

  # from nerves_bootstrap/aliases.ex#L5
  # This assumes that once the nerves environment
  # is setup at the top level, it will permeate to
  # dependencies.
  # Adds nerves deps and elixir_make to compilers list,
  # and set the clean task, if present in the final deps.
  def update_config(nerves_deps) do
    with %{} <- Mix.ProjectStack.peek(),
         %{name: name, config: config, file: file} <- Mix.ProjectStack.pop(),
         nil <- Mix.ProjectStack.peek() do
      deps_c = Keyword.get(config, :deps, [])
      deps_m = defs_map(deps_c ++ nerves_deps)
      deps_n = deps_m |> Enum.map(fn {_, dep} -> dep end)
      config = Keyword.put(config, :deps, deps_n)
      archives = Keyword.get(config, :archives, [])
      # linux only,
      makefile = file |> Path.dirname() |> Path.join("Makefile")

      # Add elixir_make and clean target only if makefile exists.
      config_n =
        with true <- File.regular?(makefile),
             true <- Map.has_key?(deps_m, :elixir_make),
             compilers <- Keyword.get(config, :compilers, []),
             false <- Enum.member?(compilers, :elixir_make) do
          config = Keyword.put(config, :make_clean, ["clean"])
          Keyword.put(config, :compilers, [:elixir_make | compilers])
        else
          _ -> config
        end

      # Update config only if ash_mix archive is present.
      case Keyword.has_key?(archives, :ash_mix) do
        true -> :ok = Mix.ProjectStack.push(name, config_n, file)
        _ -> :ok = Mix.ProjectStack.push(name, config, file)
      end
    else
      # We are not at the top of the stack. Do nothing.
      _ ->
        :ok
    end
  end
end
