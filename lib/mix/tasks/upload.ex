defmodule Mix.Tasks.Ash.Upload do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Uploads application to selected runtime"

  def run(_args) do
    Mix.Task.run("ash.build")
    ash = Ash.load_config()
    Mix.shell().info("Uploading to runtime: #{ash.runtime}")
    :ok = :ssh.start()

    {:ok, :done} =
      SFTPClient.connect([host: ash.host, port: ash.port], fn conn ->
        case SFTPClient.make_dir(conn, ash.apps_folder) do
          :ok -> :ok
          {:error, %SFTPClient.OperationError{reason: :file_already_exists}} -> :ok
          _ -> Mix.raise("Failure to create #{ash.apps_folder}")
        end

        remote_path = Path.join(ash.apps_folder, ash.escript_name)

        {:ok, ^remote_path} =
          SFTPClient.upload_file(
            conn,
            ash.escript_path,
            remote_path
          )

        :done
      end)
  end
end
