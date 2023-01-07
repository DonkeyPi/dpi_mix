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
    dpi = Dpi.basic_config(false)

    unless Map.has_key?(dpi.runtimes, rt) do
      Mix.raise("Runtime #{rt} not found in #{dpi.dpi_mix_exs_p}")
    end

    path = Dpi.find_dpi_mix_srt()
    File.write!(path, "#{rt}\n")
    Mix.shell().info("Selected runtime #{rt} into runtime file")
    Mix.shell().info("Runtime file #{path}")
    # load config to raise if runtime does not exists
    Dpi.basic_config(false)
  end
end
