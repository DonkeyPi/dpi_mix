defmodule Mix.Tasks.Ash.Select do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Selects default runtime"

  def run(args) do
    rt =
      case args do
        [rt] ->
          rt

        _ ->
          {:ok, hostname} = :inet.gethostname()
          hostname |> List.to_string()
      end

    path = Ash.find_ash_mix_srt()
    File.write!(path, "#{rt}\n")
    Mix.shell().info("Selected runtime #{rt} into runtime file")
    Mix.shell().info("Runtime file #{path}")
    # load config to raise if runtime does not exists
    Ash.basic_config(false)
  end
end
