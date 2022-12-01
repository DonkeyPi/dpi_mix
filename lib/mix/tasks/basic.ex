defmodule Mix.Tasks.Ash.Clean do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Cleans and calls make clean"

  # ensure Makefile has a clean target
  def run(args) do
    ash = Ash.get_config()
    Mix.shell().info("Cleaning for: #{Ash.runtime_id(ash)}")
    Mix.Task.run("clean", args)
  end
end

defmodule Mix.Tasks.Ash.Reset do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Deletes output folders: _build, deps"

  def run(_args) do
    ash = Ash.get_config()
    Mix.shell().info("Reseting for: #{Ash.runtime_id(ash)}")
    # remove output folders before it asks for deps.get
    File.rm_rf!("_build")
    File.rm_rf!("deps")
  end
end

defmodule Mix.Tasks.Ash.Compile do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Compiles de application"

  def run(args) do
    ash = Ash.get_config()
    Mix.shell().info("Compiling for: #{Ash.runtime_id(ash)}")
    Mix.Task.run("compile", args)
  end
end

defmodule Mix.Tasks.Ash.Test do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Tests de application"

  def run(args) do
    System.put_env("MIX_ENV", "test")
    ash = Ash.get_config()
    Mix.shell().info("Testing for: #{Ash.runtime_id(ash)}")
    Mix.Task.run("test", args)
  end
end
