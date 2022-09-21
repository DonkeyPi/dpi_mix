defmodule Mix.Tasks.Ash.Build do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Builds the application escript"

  # https://hexdocs.pm/mix/main/Mix.Tasks.Escript.Build.html
  def run(_args) do
    rt = Ash.load_runtime()
    Mix.shell().info("Building for runtime: #{rt}")
    Mix.Task.run("escript.build")
    Ash.escript_name() |> File.rename!(Ash.escript_path())
  end
end
