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
  def runtime_id(ash), do: "#{inspect({ash.runtime, ash.runtime_entry})}"

  def run(args) do
    case args do
      [] ->
        ash = init()
        Mix.shell().info("Selected runtime: #{runtime_id(ash)}")
        Mix.shell().info("Runtime file: #{ash.ash_mix_srt_p}")
        Mix.shell().info("Bundle path: #{ash.bundle_path}")
        Mix.shell().info("Config map: #{inspect(ash)}")

      [task | args] ->
        if task == "test", do: System.put_env("MIX_ENV", "test")
        ash = init()
        Mix.shell().info("Selected runtime: #{runtime_id(ash)}")
        Mix.Task.run(task, args)
    end
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

  def init() do
    config = get_config()
    update_config()
    config[:ash_config]
  end

  def get_config() do
    if Process.whereis(__MODULE__) == nil do
      config = load_config()
      Agent.start_link(fn -> config end, name: __MODULE__)
    end

    Agent.get(__MODULE__, fn config -> config end)
  end

  def get_deps(pc) do
    pc
    |> filter_deps()
    |> recurse_deps([])
  end

  def stdout(conn, chan) do
    exit_on_enter(conn)
    exit_on_ping(conn)
    stdout_loop(conn, chan)
  end

  defp update_config() do
    %{
      ash_config: %{target: target},
      nerves_deps: nerves_deps
    } = get_config()

    # Override target and reload config/config.exs.
    if Mix.target() != target do
      System.put_env("MIX_TARGET", "#{target}")
      Mix.target(target)
      Mix.Tasks.Loadconfig.run([])
    end

    update_project(nerves_deps)

    # Nerves projects auto start it in config/config.ex.
    Application.stop(:nerves_bootstrap)

    # All it does is to append aliases to core mix tasks.
    # Nerves.Bootstrap.Aliases.init could be called directly
    # as that is all the application does on init but
    # nerves checks for the app to be running later on.
    :ok = Application.ensure_started(:nerves_bootstrap)
  end

  defp load_config() do
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

    deps_path = Mix.Project.deps_path()

    ash_config = %{
      name: name,
      version: version,
      target: target,
      host: host,
      port: port,
      runtime: rt,
      deps_path: deps_path,
      build_path: build_path,
      runs_folder: @runs_folder,
      runtime_entry: rts[rt],
      ash_mix_srt_f: @ash_mix_srt,
      ash_mix_srt_p: ash_mix_srt,
      ash_mix_exs_f: @ash_mix_exs,
      ash_mix_exs_p: ash_mix_exs,
      bundle_name: bundle_name,
      bundle_path: bundle_path
    }

    %{
      ash_config: ash_config,
      nerves_deps: nerves_deps
    }
  end

  # From nerves_bootstrap/aliases.ex#L5
  # Adds nerves deps and elixir_make to compilers list,
  # and set the clean task, if present in the final deps.
  # Make file name is fixed to unix name.
  defp update_project(nerves_deps) do
    case Mix.ProjectStack.pop() do
      %{name: name, config: config, file: file} ->
        deps_c = Keyword.get(config, :deps, [])
        deps_m = defs_map(deps_c ++ nerves_deps)
        deps_n = deps_m |> Enum.map(fn {_, dep} -> dep end)
        config = Keyword.put(config, :deps, deps_n)
        archives = Keyword.get(config, :archives, [])
        makefile = file |> Path.dirname() |> Path.join("Makefile")

        # Add elixir_make and clean target only if makefile exists.
        # Clean target only added if make_clean not present already.
        # No changes at all if elixir_make is already listed.
        config_n =
          with true <- File.regular?(makefile),
               true <- Map.has_key?(deps_m, :elixir_make),
               compilers <- Keyword.get(config, :compilers, []),
               false <- Enum.member?(compilers, :elixir_make) do
            config = Keyword.put_new(config, :make_clean, ["clean"])
            Keyword.put(config, :compilers, [:elixir_make | compilers])
          else
            _ -> config
          end

        # Update config only if ash_mix archive is present.
        case Keyword.has_key?(archives, :ash_mix) do
          true -> :ok = Mix.ProjectStack.push(name, config_n, file)
          _ -> :ok = Mix.ProjectStack.push(name, config, file)
        end

      _ ->
        :ok
    end
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

  defp filter_deps(pc) do
    pc
    |> Keyword.fetch!(:deps)
    |> Enum.filter(fn
      {_n, v} when is_binary(v) -> true
      {_n, p} when is_list(p) -> Keyword.get(p, :runtime, true)
      {_n, _v, p} when is_list(p) -> Keyword.get(p, :runtime, true)
    end)
    |> Enum.map(fn
      {n, vp} -> {n, {vp}}
      {n, v, p} -> {n, {v, p}}
    end)
  end

  defp recurse_deps([], acc), do: acc

  defp recurse_deps([{name, props} | tail], acc) do
    path =
      get_config()[:ash_config][:build_path]
      |> Path.join("#{name}")

    # Ignore deps that didn't make it to the build dir after compile.
    # Mix filters out some deps because of env or target.
    # I am trusting the output of the mix compiler instead
    # of matching env and target myself.
    path = if File.dir?(path), do: get_path(name, props), else: nil
    recurse_path(path, name, tail, acc)
  end

  defp recurse_path(nil, _, tail, acc) do
    recurse_deps(tail, acc)
  end

  defp recurse_path(path, name, tail, acc) do
    acc =
      Mix.Project.in_project(name, path, fn _module ->
        Mix.Project.config()
        |> filter_deps()
        |> recurse_deps([])
      end) ++ acc

    recurse_deps(tail, [name | acc])
  end

  defp get_path(name, props) do
    path =
      case props do
        {v} when is_binary(v) ->
          # Use cached root deps_path
          get_config()[:ash_config][:deps_path]
          |> Path.join("#{name}")

        {p} when is_list(p) ->
          Keyword.get(p, :path)

        {_, p} when is_list(p) ->
          Keyword.get(p, :path)
      end

    if File.dir?(path), do: path, else: nil
  end

  defp defs_map(deps) do
    for dep <- deps, into: %{} do
      case dep do
        {n, vp} -> {n, {n, vp}}
        {n, v, p} -> {n, {n, v, p}}
      end
    end
  end
end
