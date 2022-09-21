defmodule Mix.Tasks.Ash.Runtime do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Selects default runtime"

  def run(args) do
    case args do
      [rt] ->
        path = Ash.runtime_path()
        File.write!(path, "#{rt}\n")
        Mix.shell().info("Selected runtime #{rt} into .runtime file")

      _ ->
        Mix.shell().error("Invalid task arguments: #{inspect(args)}")
        Mix.shell().error("Usage: mix ash.runtime <runtime>")
    end
  end
end
