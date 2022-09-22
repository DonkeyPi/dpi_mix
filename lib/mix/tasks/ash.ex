defmodule Mix.Tasks.Ash do
  use Mix.Task

  @default_port 8022
  @apps_folder "/ash_apps"
  @runtime_path ".runtime"

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

    rtc = rts[rt]
    host = Keyword.fetch!(rtc, :host)
    port = Keyword.get(rtc, :port, @default_port)

    name = pc |> Keyword.fetch!(:app)
    version = pc |> Keyword.fetch!(:version)

    build_path = Mix.Project.build_path()

    bundle_name =
      pc
      |> Keyword.fetch!(:app)
      |> Atom.to_string()

    bundle_path =
      build_path
      |> Path.join(bundle_name)

    %{
      name: name,
      version: version,
      host: host,
      port: port,
      runtime: rt,
      build_path: build_path,
      apps_folder: @apps_folder,
      runtime_path: @runtime_path,
      bundle_name: bundle_name,
      bundle_path: bundle_path
    }
  end

  def run(_args) do
    ash = load_config()
    Mix.shell().info("selected runtime: #{ash.runtime}")
    Mix.shell().info("runtime file: #{ash.runtime_path}")
    Mix.shell().info("bundle path: #{ash.bundle_path}")
    Mix.shell().info("config map: #{inspect(ash)}")
  end
end
