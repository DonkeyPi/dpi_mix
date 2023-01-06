defmodule Mix.Tasks.Dpi.Reset do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Deletes output folders: _build, deps"

  def run(_args) do
    dpi = Dpi.init()
    Mix.shell().info("Reseting for: #{Dpi.runtime_id(dpi)}")
    # remove output folders before it asks for deps.get
    File.rm_rf!("_build")
    File.rm_rf!("deps")
  end
end
