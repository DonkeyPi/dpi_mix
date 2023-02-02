defmodule Dpi.Mix.Helper do
  @base "rsync://yeico.com/dpi"
  @tmp "/tmp/dpi_mix"
  @root "~/.dpi_mix"

  def remote(path), do: "#{@base}/#{path}"
  def local(path), do: Path.join(@root, path) |> Path.expand()
  def local(), do: @root |> Path.expand()
  def tmp(path), do: Path.join(@tmp, path)
  def tmp(), do: @tmp

  def rsync_get(remote, local) do
    cmd_stdio("rsync", [remote, local])
  end

  def rsync_get_r(remote, local) do
    cmd_stdio("rsync", ["-r", remote, local])
  end

  def cmd_stdio(cmd, args) do
    # relative paths must be of the form
    # ./exec, ../exec, or bin/exec
    exec =
      case String.contains?(cmd, "/") do
        true -> cmd
        false -> System.find_executable(cmd)
      end

    if exec == nil, do: raise("#{cmd} not found")

    port =
      Port.open(
        {:spawn_executable, exec},
        [:binary, :exit_status, :stderr_to_stdout, args: args]
      )

    handle = fn handle ->
      receive do
        {^port, {:data, data}} ->
          :ok = IO.binwrite(:stdio, data)
          handle.(handle)

        {^port, {:exit_status, 0}} ->
          :done

        {^port, {:exit_status, status}} ->
          Mix.raise("Exit status #{status} for #{cmd}")
          :done

        other ->
          raise "#{inspect(other)}"
      end
    end

    handle.(handle)
  end
end
