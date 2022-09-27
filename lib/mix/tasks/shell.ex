defmodule Mix.Tasks.Ash.Shell do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Connect to app shell"

  def run(_args) do
    ash = Ash.load_config()
    Mix.shell().info("Connecting to app shell: #{ash.name}@#{ash.host}")
    host = ash.host |> String.to_charlist()
    user = "#{ash.name}" |> String.to_charlist()
    opts = [silently_accept_hosts: true, user: user]
    :ok = :ssh.start()
    Mix.shell().info("ssh -p8022 #{ash.name}@#{ash.host}")
    :ssh.shell(host, ash.port, opts)
  end
end
