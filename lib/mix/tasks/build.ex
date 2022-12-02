defmodule Mix.Tasks.Ash.Build do
  use Mix.Task
  alias Mix.Tasks.Ash

  @shortdoc "Builds application for selected runtime"

  def run(_args) do
    ash = Ash.init()
    Mix.shell().info("Building for: #{Ash.runtime_id(ash)}")
    Mix.Task.run("compile")
    deps = Mix.Project.config() |> Ash.get_deps()
    apps = [ash.name | deps]

    paths =
      for app <- apps do
        Path.join("lib", "#{app}") |> String.to_charlist()
      end

    # priv folder are linked back from _build/app/priv
    saved =
      Enum.filter(paths, fn path ->
        app = Path.join(ash.build_path, path)
        priv = Path.join(app, "priv")
        save = Path.join(ash.build_path, "#{path}.priv")

        case File.read_link(priv) do
          {:ok, link} ->
            File.write!(save, link)

            real =
              Path.join(app, link)
              |> Path.expand()

            File.rm_rf!(priv)
            File.mkdir!(priv)
            File.cp_r!(real, priv)
            true

          _ ->
            false
        end
      end)

    cwd = File.cwd!()
    :ok = File.cd!(ash.build_path)
    # dereference makes for huge files that install slow
    opts = [:compressed]
    bundle_path = ash.bundle_path |> String.to_charlist()
    :ok = :erl_tar.create(bundle_path, paths, opts)
    :ok = File.cd!(cwd)
    Mix.shell().info("Bundle : #{bundle_path}")
    # tar -tvf _build/dev/*.tgz

    # put links back to avoid stalled files
    Enum.each(saved, fn path ->
      app = Path.join(ash.build_path, path)
      priv = Path.join(app, "priv")
      save = Path.join(ash.build_path, "#{path}.priv")
      link = File.read!(save)
      real = Path.join(app, link)
      File.rm_rf!(priv)
      File.ln_s!(real, priv)
      File.rm_rf!(save)
    end)
  end
end
