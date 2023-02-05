defmodule Mix.Tasks.Dpi.Wget do
  use Mix.Task
  alias Mix.Tasks.Dpi

  # press Super+PrtScreen
  # to get /tmp/dpi_runtime/screenshot.png
  # use mix dpi.wget screenshot.png
  @shortdoc "Downloads files from selected runtime"

  def run(args) do
    path =
      case args do
        [path] -> path
        _ -> Mix.raise("Invalid path")
      end

    :ok = :ssh.start()
    dpi = Dpi.basic_config(false)
    Mix.shell().info("Downloading from: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("File path: #{path}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, chan, conn} = :ssh_sftp.start_channel(host, dpi.port, opts)
    {:ok, data} = :ssh_sftp.read_file(chan, path)
    :ok = :ssh_sftp.stop_channel(chan)
    File.write!(Path.basename(path), data)
    :ok = :ssh.close(conn)
  end
end
