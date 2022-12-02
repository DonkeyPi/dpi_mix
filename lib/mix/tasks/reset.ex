defmodule Mix.Tasks.Ash.Reset do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Deletes output folders: _build, deps"

  def run(_args) do
    ash = Ash.init()
    Mix.shell().info("Reseting for: #{Ash.runtime_id(ash)}")
    # remove output folders before it asks for deps.get
    File.rm_rf!("_build")
    File.rm_rf!("deps")
  end
end
