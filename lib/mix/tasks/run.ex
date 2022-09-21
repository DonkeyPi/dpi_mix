defmodule Mix.Tasks.Ash.Run do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Runs application against selected runtime"

  def run(_args) do
    Mix.Task.run("ash.upload")
    ash = Ash.load_config()
    Mix.shell().info("Running on runtime: #{ash.runtime}")
    {:ok, ip} = ash.host |> String.to_charlist() |> :inet.getaddr(:inet)
    ip = ip |> :inet_parse.ntoa()
    {:ok, conn} = SSHEx.connect(ip: ip, port: ash.port)
    stream = SSHEx.stream(conn, 'run :#{ash.escript_name}')
    IO.inspect({conn, stream})

    Stream.each(stream, fn msg ->
      IO.inspect(msg)

      case msg do
        {:stdout, row} -> IO.puts(row)
        {:stderr, row} -> IO.puts(row)
        {:status, status} -> IO.puts("Exit status #{status}")
        {:error, reason} -> IO.puts("Error #{inspect(reason)}")
      end
    end)
  end
end
