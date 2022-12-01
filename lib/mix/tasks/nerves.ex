defmodule Mix.Tasks.Ash.Fw do
  def check_no_host() do
    if Mix.target() == :host do
      Mix.raise("Select a runtime with target different than :host")
    end
  end

  defmodule Build do
    use Mix.Task
    alias Mix.Tasks.Ash

    @shortdoc "Build the firmware."

    def run(args) do
      ash = Ash.get_config()
      Mix.shell().info("Firmware for: #{Ash.runtime_id(ash)}")
      Mix.Tasks.Ash.Fw.check_no_host()
      Mix.Task.run("firmware", args)
    end
  end

  defmodule Upload do
    use Mix.Task
    alias Mix.Tasks.Ash

    @shortdoc "Uploads the firmware"

    def run(args) do
      ash = Ash.get_config()
      Mix.shell().info("Uploading for: #{Ash.runtime_id(ash)}")
      Mix.Tasks.Ash.Fw.check_no_host()
      Mix.Task.run("firmware")
      Mix.Task.run("upload", [ash.host | args])
    end
  end

  defmodule Burn do
    use Mix.Task
    alias Mix.Tasks.Ash

    @shortdoc "Build and burns a firmware."

    def run(args) do
      ash = Ash.get_config()
      Mix.shell().info("Burning for: #{Ash.runtime_id(ash)}")
      Mix.Tasks.Ash.Fw.check_no_host()
      Mix.Task.run("firmware.burn", args)
    end
  end

  defmodule Image do
    use Mix.Task
    alias Mix.Tasks.Ash

    @shortdoc "Build and burns a firmware."

    def run(args) do
      ash = Ash.get_config()
      Mix.shell().info("Image for: #{Ash.runtime_id(ash)}")
      Mix.Tasks.Ash.Fw.check_no_host()
      Mix.Task.run("firmware.image", args)
    end
  end
end
