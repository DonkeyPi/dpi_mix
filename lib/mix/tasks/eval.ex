defmodule Mix.Tasks.Ash.Eval do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Evaluate expression on app vm"

  def run(args) do
    :ssh.start()
    path_code = Enum.join(args, " ")
    ash = Ash.load_config()

    {type, value, code} =
      if String.starts_with?(path_code, "file:") do
        path_code = String.replace_leading(path_code, "file:", "")
        {"file", path_code, File.read!(path_code)}
      else
        {"code", path_code, path_code}
      end

    Mix.shell().info("Evaluating on: #{ash.name}@#{ash.runtime}")
    Mix.shell().info("Evaluating #{type}: #{value}")
    host = ash.host |> String.to_charlist()
    user = ash.name |> Atom.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    {:ok, conn} = :ssh.connect(host, ash.port, opts)
    {:ok, chan} = :ssh_connection.session_channel(conn, Ash.toms())
    :success = :ssh_connection.subsystem(conn, chan, 'runtime', Ash.toms())
    :ok = :ssh_connection.send(conn, chan, "eval " <> code, Ash.toms())
    Ash.stdout(conn, chan)
  end
end
