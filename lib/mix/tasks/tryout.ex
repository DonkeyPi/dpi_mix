defmodule Mix.Tasks.Ash.Tryout do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Tryout task"

  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("config: #{inspect(ash)}")
    Mix.Task.run("release")
  end
end
