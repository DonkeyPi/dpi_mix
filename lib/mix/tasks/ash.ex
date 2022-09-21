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

    escript_name =
      pc
      |> Keyword.fetch!(:app)
      |> Atom.to_string()

    escript_path =
      Mix.Project.build_path()
      |> Path.join(escript_name)

    %{
      host: host,
      port: port,
      runtime: rt,
      apps_folder: @apps_folder,
      runtime_path: @runtime_path,
      escript_name: escript_name,
      escript_path: escript_path
    }
  end

  def run(_args) do
    ash = load_config()
    Mix.shell().info("runtime file: #{ash.runtime_path}")
    Mix.shell().info("escript file: #{ash.escript_path}")
    Mix.shell().info("selected runtime: #{ash.runtime}")
  end
end
