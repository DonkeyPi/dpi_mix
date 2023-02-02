defmodule Mix.Tasks.Dpi.Upload do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Uploads application to selected runtime"

  def run(args) do
    Mix.Task.run("dpi.build")
    dpi = Dpi.init()
    Mix.shell().info("Uploading to: #{Dpi.runtime_id(dpi)}")
    Mix.shell().info("Uploading bundle: #{dpi.bundle_name}")
    host = dpi.host |> String.to_charlist()
    user = dpi.name |> Atom.to_charlist()

    keep =
      case args do
        ["keep"] -> true
        _ -> false
      end

    upload(host, dpi.port, user, dpi.runs_folder, dpi.bundle_path, keep)
  end

  def upload(host, port, user, runs_folder, bundle_path, keep) do
    :ok = :ssh.start()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, chan, conn} = :ssh_sftp.start_channel(host, port, opts)

    :ok =
      case :ssh_sftp.make_dir(chan, runs_folder) do
        :ok -> :ok
        {:error, :file_already_exists} -> :ok
        _ -> Mix.raise("Failure to create #{runs_folder}")
      end

    data = File.read!(bundle_path)
    bundle_name = Path.basename(bundle_path)
    remote_path = Path.join(runs_folder, bundle_name)
    :ok = :ssh_sftp.write_file(chan, remote_path, data)
    :ok = :ssh_sftp.stop_channel(chan)

    case keep do
      true -> Process.put(:ssh_conn, conn)
      _ -> :ok = :ssh.close(conn)
    end
  end
end
