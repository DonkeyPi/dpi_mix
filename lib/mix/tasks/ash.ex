defmodule Mix.Tasks.Ash do
  use Mix.Task
  @default_port 8022
  @apps_folder "/ash_apps"

  def default_port(), do: @default_port
  def apps_folder(), do: @apps_folder

  def runtime_path() do
    ".runtime"
  end

  def escript_name() do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
    |> Atom.to_string()
  end

  def escript_path() do
    Mix.Project.build_path()
    |> Path.join(escript_name())
  end

  def load_runtime() do
    path = runtime_path()

    unless File.exists?(path) do
      Mix.raise("Runtime not selected, use: mix ash.runtime <runtime>")
    end

    path
    |> File.read!()
    |> String.trim()
  end

  def runtime_config(rt) do
    Mix.Project.config()
    |> Keyword.fetch!(:runtimes)
    |> Enum.map(fn {k, v} -> {"#{k}", v} end)
    |> Enum.into(%{})
    |> Map.fetch!(rt)
  end

  def run(_args) do
    Mix.shell().info("runtime file: #{runtime_path()}")
    Mix.shell().info("escript file: #{escript_path()}")
  end
end
