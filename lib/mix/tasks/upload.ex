defmodule Mix.Tasks.Ash.Upload do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Uploads application to selected runtime"

  def run(_args) do
    Mix.Task.run("ash.build")
    ash = Ash.load_config()
    Mix.shell().info("Uploading to runtime: #{ash.runtime}@#{ash.host}:#{ash.port}")
    :ok = :ssh.start()
    host = ash.host |> String.to_charlist()
    opts = [silently_accept_hosts: true]
    {:ok, chan, conn} = :ssh_sftp.start_channel(host, ash.port, opts)

    :ok =
      case :ssh_sftp.make_dir(chan, ash.apps_folder) do
        :ok -> :ok
        {:error, :file_already_exists} -> :ok
        _ -> Mix.raise("Failure to create #{ash.apps_folder}")
      end

    data = File.read!(ash.escript_path)
    remote_path = Path.join(ash.apps_folder, ash.escript_name)
    :ok = :ssh_sftp.write_file(chan, remote_path, data)
    :ok = :ssh_sftp.stop_channel(chan)
    :ok = :ssh.close(conn)
  end
end
