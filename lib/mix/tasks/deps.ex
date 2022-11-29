defmodule Mix.Tasks.Ash.Deps do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Manage dependencies for selected runtime"

  def run(args) do
    ash = Ash.get_config()
    Mix.shell().info("Dependencies on: #{Ash.runtime_id(ash)}")

    case args do
      [] -> Mix.Task.run("deps", args)
      [task | args] -> Mix.Task.run("deps.#{task}", args)
    end
  end
end
