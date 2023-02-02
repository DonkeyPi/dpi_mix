defmodule Mix.Tasks.Dpi.Install do
  use Mix.Task
  alias Mix.Tasks.Dpi
  alias Mix.Tasks.Dpi.Upload

  @shortdoc "Installs application on selected runtime"

  def run(args) do
    dpi =
      case args do
        [] ->
          Mix.Task.run("dpi.upload", ["keep"])
          Dpi.init()

        [bundle_path] ->
          dpi = Dpi.basic_config(false)
          Mix.shell().info("Uploading to: #{Dpi.runtime_id(dpi)}")
          Mix.shell().info("Uploading bundle: #{bundle_path}")
          host = dpi.host |> String.to_charlist()
          app_name = Path.basename(bundle_path, ".tgz")
          user = app_name |> String.to_charlist()
          Upload.upload(host, dpi.port, user, dpi.runs_folder, bundle_path, true)
          dpi
      end

    Mix.shell().info("Installing on: #{Dpi.runtime_id(dpi)}")
    conn = Process.get(:ssh_conn)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "install", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
