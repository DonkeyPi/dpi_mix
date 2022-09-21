defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Runs application against selected runtime"

  def run(_args) do
    Mix.Task.run("ash.build")
    rt = Ash.load_runtime()
    Mix.shell().info("Running on runtime: #{rt}")
    System.cmd(Ash.escript_path(), [])
  end
end
