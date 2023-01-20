defmodule Mix.Tasks.Dpi.Upload do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Uploads application to selected runtime"

  def run(args) do
    :ok = :ssh.start()
    Mix.Task.run("dpi.build")
    dpi = Dpi.init()
    Mix.shell().info("Uploading to: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("Uploading bundle: #{dpi.bundle_name}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, chan, conn} = :ssh_sftp.start_channel(host, dpi.port, opts)

    :ok =
      case :ssh_sftp.make_dir(chan, dpi.runs_folder) do
        :ok -> :ok
        {:error, :file_already_exists} -> :ok
        _ -> Mix.raise("Failure to create #{dpi.runs_folder}")
      end

    data = File.read!(dpi.bundle_path)
    remote_path = Path.join(dpi.runs_folder, dpi.bundle_name)
    :ok = :ssh_sftp.write_file(chan, remote_path, data)
    :ok = :ssh_sftp.stop_channel(chan)

    case args do
      ["keep"] -> Process.put(:ssh_conn, conn)
      _ -> :ok = :ssh.close(conn)
    end
  end
end
