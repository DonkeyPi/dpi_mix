defmodule Mix.Tasks.Dpi do
  use Mix.Task

  @default_port 8022
  @runs_folder "/dpi_runs"
  # ~/.dpi_runtime is runtime folder
  @dpi_mix_srt ".dpi_mix.srt"
  @dpi_mix_exs ".dpi_mix.exs"

  # global timeout
  @toms 5_000

  # initial monitor delay
  @moms 2_000

  def toms(), do: @toms
  def dpi_mix_srt(), do: @dpi_mix_srt
  def find_dpi_mix_srt(), do: find_path(@dpi_mix_srt, @dpi_mix_srt)
  def runtime_id(dpi), do: "#{inspect({dpi.runtime, dpi.runtime_entry})}"
  def init(), do: get_config().dpi_config

  def run(args) do
    case args do
      [] ->
        dpi = init()
        Mix.shell().info("Selected runtime: #{runtime_id(dpi)}")
        Mix.shell().info("Runtime file: #{dpi.dpi_mix_srt_p}")
        Mix.shell().info("Bundle path: #{dpi.bundle_path}")
        Mix.shell().info("Config map: #{inspect(dpi)}")

      ["upload"] ->
        dpi = init()
        Mix.shell().info("Selected runtime: #{runtime_id(dpi)}")
        Mix.Task.run("upload", [dpi.host])

      [task | args] ->
        if task == "test", do: System.put_env("MIX_ENV", "test")
        dpi = init()
        Mix.shell().info("Selected runtime: #{runtime_id(dpi)}")
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
    |> Enum.uniq()
  end

  def stdout(conn, chan) do
    exit_on_enter(conn)
    exit_on_ping(conn)
    stdout_loop(conn, chan)
  end

  defp update_config(target, variant, nerves_deps) do
    System.put_env("MIX_VARIANT", "#{variant}")
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

  def basic_config(with_app, rt \\ nil) do
    dpi_mix_exs = find_path(@dpi_mix_exs, @dpi_mix_exs)
    dpi_mix_srt = find_path(@dpi_mix_srt, @dpi_mix_srt)

    unless File.exists?(dpi_mix_exs) do
      Mix.raise("Runtime not configured, create file #{@dpi_mix_exs}")
    end

    rt =
      if rt == nil do
        unless File.exists?(dpi_mix_srt) do
          Mix.raise("Runtime not selected, use: mix dpi.select <runtime>")
        end

        dpi_mix_srt
        |> File.read!()
        |> String.trim()
        |> String.to_atom()
      else
        rt
      end

    dot_config =
      dpi_mix_exs
      |> Code.eval_file()
      |> elem(0)

    rts =
      dot_config
      |> Keyword.get(:dpi_runtimes, [])
      |> Enum.into(%{})

    unless Map.has_key?(rts, rt) do
      Mix.raise("Runtime #{rt} not found in #{dpi_mix_exs}")
    end

    rtc = Map.fetch!(rts, rt) |> rt_defaults()
    root = dpi_mix_exs |> Path.dirname()

    %{
      name: :dpi,
      bid: rtc[:bid],
      variant: rtc[:variant],
      target: rtc[:target],
      host: rtc[:host],
      port: rtc[:port],
      runtime: rt,
      runtimes: rts,
      dot_config: dot_config,
      runtime_entry: rtc,
      root: root,
      runs_folder: @runs_folder,
      dpi_mix_srt_f: @dpi_mix_srt,
      dpi_mix_srt_p: dpi_mix_srt,
      dpi_mix_exs_f: @dpi_mix_exs,
      dpi_mix_exs_p: dpi_mix_exs
    }
    |> load_app(with_app)
  end

  def rt_defaults(rtc) do
    host = Keyword.get(rtc, :host, "localhost")
    target = Keyword.get(rtc, :target, :host)

    rtc
    |> Keyword.put_new(:host, "localhost")
    |> Keyword.put_new(:port, @default_port)
    |> Keyword.put_new(:target, :host)
    |> Keyword.put_new(:variant, target)
    |> Keyword.put_new(:bid, host)
  end

  defp load_app(map, false), do: map

  defp load_app(map, true) do
    unless File.exists?("mix.exs") do
      Mix.raise("No mix.exs in current folder.")
    end

    pc = Mix.Project.config()
    name = pc |> Keyword.fetch!(:app)
    version = pc |> Keyword.fetch!(:version)
    Map.merge(map, %{pc: pc, name: name, version: version})
  end

  defp load_config() do
    dpi = basic_config(true)

    nerves_deps? = dpi.dot_config |> Keyword.has_key?(:nerves_deps)
    nerves_deps = dpi.dot_config |> Keyword.get(:nerves_deps, nerves_deps())

    # relative to .dpi_mix.exs
    nerves_deps =
      case nerves_deps? do
        true -> relative_deps(dpi.root, nerves_deps)
        false -> nerves_deps
      end

    # Change target before build_path is cached.
    update_config(dpi.target, dpi.variant, nerves_deps)

    build_path = Mix.Project.build_path()

    bundle_name =
      dpi.pc
      |> Keyword.fetch!(:app)
      |> Atom.to_string()
      |> String.replace_suffix("", ".tgz")

    bundle_path =
      build_path
      |> Path.join(bundle_name)

    deps_path = Mix.Project.deps_path()

    config = %{
      deps_path: deps_path,
      build_path: build_path,
      bundle_name: bundle_name,
      bundle_path: bundle_path
    }

    %{
      dpi_config: Map.merge(dpi, config),
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
        makefile = file |> Path.dirname() |> Path.join("Makefile")

        # Add elixir_make and clean target only if makefile exists.
        # Clean target only added if make_clean not present already.
        # No changes at all if elixir_make is already listed.
        config =
          with true <- File.regular?(makefile),
               true <- Map.has_key?(deps_m, :elixir_make),
               compilers <- Keyword.get(config, :compilers, []),
               false <- Enum.member?(compilers, :elixir_make) do
            config = Keyword.put_new(config, :make_clean, ["clean"])

            compilers =
              case compilers do
                [] -> [:elixir_make | Mix.compilers()]
                _ -> [:elixir_make | compilers]
              end

            Keyword.put(config, :compilers, compilers)
          else
            _ -> config
          end

        :ok = Mix.ProjectStack.push(name, config, file)

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
    # Use cached root build_path
    path =
      get_config()[:dpi_config][:build_path]
      |> Path.join("lib")
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
        |> Enum.uniq()
      end) ++ acc

    recurse_deps(tail, [name | acc])
  end

  defp get_path(name, props) do
    path =
      case props do
        {v} when is_binary(v) ->
          # Use cached root deps_path
          get_config()[:dpi_config][:deps_path]
          |> Path.join("#{name}")

        {p} when is_list(p) ->
          Keyword.get(p, :path)

        {_, p} when is_list(p) ->
          Keyword.get(p, :path)
      end

    # FIXME: :elixir_make returns nil path after adding timezone dep to dpi_app
    if path != nil and File.dir?(path), do: path, else: nil
  end

  defp defs_map(deps) do
    for dep <- deps, into: %{} do
      case dep do
        {n, vp} -> {n, {n, vp}}
        {n, v, p} -> {n, {n, v, p}}
      end
    end
  end

  def user_dir(), do: user_dir(File.cwd!())

  def user_dir("/"), do: nil

  def user_dir(cwd) do
    dir = Path.join(cwd, ".ssh")

    case File.dir?(dir) do
      true -> dir
      _ -> Path.dirname(cwd) |> user_dir()
    end
  end

  def add_user_dir(opts) do
    case user_dir() do
      nil -> opts
      dir -> opts ++ [user_dir: String.to_charlist(dir)]
    end
  end

  def relative_deps(root, nerves_deps) do
    for {name, props} <- nerves_deps do
      props =
        case Keyword.has_key?(props, :path) do
          false ->
            props

          true ->
            path = Keyword.fetch!(props, :path)
            path = Path.join(root, path)
            Keyword.put(props, :path, path)
        end

      {name, props}
    end
  end

  def nerves_deps() do
    [
      {:nerves, "1.9.1", runtime: false},
      {:nerves_system_rpi3, "~> 1.20.2", runtime: false, targets: :rpi3},
      {:nerves_system_rpi4, "~> 1.20.2", runtime: false, targets: :rpi4},
      {:elixir_make, "0.7.2", runtime: false}
    ]
  end
end
