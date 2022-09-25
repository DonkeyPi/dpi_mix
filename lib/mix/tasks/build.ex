defmodule Mix.Tasks.Ash.Build do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Builds application for selected runtime"

  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Building for runtime: #{ash.runtime}")
    Mix.Task.run("compile")
    bundle_path = ash.bundle_path |> String.to_charlist()
    build_path = ash.build_path |> String.to_charlist()
    opts = [cwd: build_path, compress: :all]
    apps = [ash.name | ash.deps]

    paths =
      for app <- apps do
        Path.join("lib", "#{app}") |> String.to_charlist()
      end

    {:ok, ^bundle_path} = :zip.create(bundle_path, paths, opts)
    Mix.shell().info("Bundle : #{bundle_path}")
  end
end
