defmodule Mix.Tasks.Ash.Build do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Builds application for selected runtime"

  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Building for runtime: #{ash.runtime}")
    Mix.Task.run("compile")
    bundle_path = ash.bundle_path |> String.to_charlist()
    # dereference -> local dependencies are links
    opts = [:compressed, :dereference]
    apps = [ash.name | ash.deps]

    paths =
      for app <- apps do
        Path.join("lib", "#{app}") |> String.to_charlist()
      end

    cwd = File.cwd!()
    :ok = File.cd!(ash.build_path)
    :ok = :erl_tar.create(bundle_path, paths, opts)
    :ok = File.cd!(cwd)
    Mix.shell().info("Bundle : #{bundle_path}")
    # tar -tvf _build/dev/*.tar
  end
end
