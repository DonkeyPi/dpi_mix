defmodule Mix.Tasks.Ash.Build do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Builds application for selected runtime"

  # https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html
  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Building for runtime: #{ash.runtime}")
    Mix.Task.run("escript.build")
    ash.escript_name |> File.rename!(ash.escript_path)
  end
end
