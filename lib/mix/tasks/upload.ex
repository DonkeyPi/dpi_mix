defmodule Mix.Tasks.Ash.Upload do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Uploads application to selected runtime"

  def run(_args) do
    Mix.Task.run("ash.build")
    rt = Ash.load_runtime()
    rtc = Ash.runtime_config(rt)
    host = Keyword.fetch!(rtc, :host)
    port = Keyword.get(rtc, :port, Ash.default_port())
    Mix.shell().info("Uploading to runtime: #{rt}")
    :ok = :ssh.start()

    {:ok, :done} =
      SFTPClient.connect([host: host, port: port], fn conn ->
        case SFTPClient.make_dir(conn, Ash.apps_folder()) do
          :ok -> :ok
          {:error, %SFTPClient.OperationError{reason: :file_already_exists}} -> :ok
          _ -> Mix.raise("Failure to create #{Ash.apps_folder()}")
        end

        remote_path = Path.join(Ash.apps_folder(), Ash.escript_name())

        {:ok, ^remote_path} =
          SFTPClient.upload_file(
            conn,
            Ash.escript_path(),
            remote_path
          )

        :done
      end)
  end
end
