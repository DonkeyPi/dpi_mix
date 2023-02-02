defmodule Mix.Tasks.Dpi.Release.List do
  use Mix.Task
  alias Dpi.Mix.Helper

  @shortdoc "List published releases"
  @releases "releases.txt"

  def run(_args) do
    remote = Helper.remote(@releases)
    local = Helper.local(@releases)
    local |> Path.dirname() |> File.mkdir_p!()
    Helper.rsync_get(remote, local)
    Helper.cmd_stdio("cat", [local])
  end
end
