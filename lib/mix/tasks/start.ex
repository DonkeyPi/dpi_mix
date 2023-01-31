defmodule Mix.Tasks.Dpi.Start do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Starts application on selected runtime"

  def run(args) do
    {with_app, app_name} =
      case {args, File.exists?("mix.exs")} do
        {[app_name], _} -> {false, app_name}
        {[], true} -> {true, nil}
        {[], _} -> Mix.raise("Not in app folder")
      end

    :ssh.start()
    dpi = Dpi.basic_config(with_app)
    app_name = if with_app, do: dpi.name, else: app_name
    Mix.shell().info("Starting on: #{Dpi.runtime_id(dpi)}")
    host = dpi.host |> String.to_charlist()
    user = "#{app_name}" |> String.to_charlist()
    opts = [silently_accept_hosts: true, user: user] |> Dpi.add_user_dir()
    {:ok, conn} = :ssh.connect(host, dpi.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Dpi.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Dpi.toms())
    :ok = :ssh_connection.send(conn, chan, "start", Dpi.toms())
    Dpi.stdout(conn, chan)
  end
end
