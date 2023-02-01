defmodule Mix.Tasks.Dpi.Select do
  use Mix.Task
  alias Mix.Tasks.Dpi

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

    rt = rt |> String.to_atom()
    Dpi.basic_config(false, rt)

    path = Dpi.find_dpi_mix_srt()
    File.write!(path, "#{rt}\n")
    Mix.shell().info("Selected runtime #{rt} into runtime file")
    Mix.shell().info("Runtime file #{path}")
  end
end
