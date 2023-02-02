defmodule Mix.Tasks.Dpi.Release.Install do
  use Mix.Task
  alias Dpi.Mix.Helper

  @shortdoc "Install release"

  def run(args) do
    case args do
      [version] -> install(version)
      _ -> Mix.raise("Usage: mix dpi.release.install <version>")
    end
  end

  defp install(version) do
    release = "release-#{version}"
    local = Helper.local()
    remote = Helper.remote(release)
    Helper.rsync_get_r(remote, local)
  end
end
