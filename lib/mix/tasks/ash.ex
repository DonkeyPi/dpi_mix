defmodule Mix.Tasks.Ash do
  use Mix.Task

  @default_port 8022
  @runs_folder "/ash_runs"
  @runtime_path ".runtime"
  @cookie_path ".cookie"

  @toms 5_000
  @moms 2_000

  def toms(), do: @toms
  def runtime_path(), do: @runtime_path

  def load_config() do
    unless File.exists?(@runtime_path) do
      Mix.raise("Runtime not selected, use: mix ash.runtime <runtime>")
    end

    rt =
      @runtime_path
      |> File.read!()
      |> String.trim()

    pc = Mix.Project.config()

    rts =
      pc
      |> Keyword.fetch!(:runtimes)
      |> Enum.map(fn {k, v} -> {"#{k}", v} end)
      |> Enum.into(%{})

    # fixme: how to filter/include deps of deps
    deps =
      pc
      |> Keyword.fetch!(:deps)
      |> Enum.filter(fn
        {_n, v} when is_binary(v) -> true
        {_n, p} when is_list(p) -> Keyword.get(p, :runtime, true)
        {_n, _v, p} when is_list(p) -> Keyword.get(p, :runtime, true)
      end)
      |> Enum.map(fn
        {n, _p} -> n
        {n, _v, _p} -> n
      end)

    rtc = Map.fetch!(rts, rt)
    host = Keyword.fetch!(rtc, :host)
    port = Keyword.get(rtc, :port, @default_port)

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
      host: host,
      port: port,
      runtime: rt,
      build_path: build_path,
      runs_folder: @runs_folder,
      runtime_path: @runtime_path,
      cookie_path: @cookie_path,
      bundle_name: bundle_name,
      bundle_path: bundle_path
    }
  end

  def stdout(conn, chan) do
    receive do
      {:ssh_cm, _, {:data, _, _, data}} ->
        IO.binwrite(data)
        stdout(conn, chan)

      {:ssh_cm, _, {:eof, _}} ->
        :ok = :ssh_connection.close(conn, chan)
        :ok = :ssh.close(conn)
    end
  end

  # check the runtime is still alive
  def monitor(conn) do
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

  def run(_args) do
    ash = load_config()
    Mix.shell().info("selected runtime: #{ash.runtime}")
    Mix.shell().info("runtime file: #{ash.runtime_path}")
    Mix.shell().info("bundle path: #{ash.bundle_path}")
    Mix.shell().info("config map: #{inspect(ash)}")
  end
end
