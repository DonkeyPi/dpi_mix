defmodule Mix.Tasks.Dpi.Build do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Builds application for selected runtime"
  @bdconfig "config/config.exs"
  @rtconfig "config/dpi.exs"

  def run(_args) do
    dpi = Dpi.init()
    Mix.shell().info("Building for: #{Dpi.runtime_id(dpi)}")
    Mix.Task.run("compile")

    rtconfig = Path.join(["lib", "#{dpi.name}.exs"])
    rtconfigp = Path.join(dpi.build_path, rtconfig)

    if File.exists?(@rtconfig) do
      File.copy!(@rtconfig, rtconfigp)
    else
      File.write!(rtconfigp, "import Config\n")
    end

    bdconfig = Path.join(["lib", "#{dpi.name}.env"])
    bdconfigp = Path.join(dpi.build_path, bdconfig)

    if File.exists?(@bdconfig) do
      contents = File.read!(@bdconfig)
      eval = Config.Reader.eval!(@bdconfig, contents, env: Mix.env())
      File.write!(bdconfigp, :erlang.term_to_binary(eval))
    else
      File.write!(bdconfigp, :erlang.term_to_binary([]))
    end

    deps = Mix.Project.config() |> Dpi.get_deps()
    apps = [dpi.name | deps]

    paths =
      for app <- apps do
        Path.join("lib", "#{app}") |> String.to_charlist()
      end

    # priv folder are linked back from _build/app/priv
    # phoenix/athasha : ebin, include
    Enum.each(paths, fn path ->
      replace_links(dpi.build_path, path)
    end)

    cwd = File.cwd!()
    :ok = File.cd!(dpi.build_path)
    # dereference makes for huge files that install slow
    opts = [:compressed]
    bundle_path = dpi.bundle_path |> String.to_charlist()
    rtconfig = rtconfig |> String.to_charlist()
    bdconfig = bdconfig |> String.to_charlist()
    includes = [rtconfig, bdconfig] ++ paths
    :ok = :erl_tar.create(bundle_path, includes, opts)
    :ok = File.cd!(cwd)
    Mix.shell().info("Bundle : #{bundle_path}")
    # tar -tvf _build/dev/*.tgz

    # put links back to avoid stalled files
    # phoenix/athasha
    Enum.each(paths, fn path ->
      restore_links(dpi.build_path, path)
    end)
  end

  def replace_links(build_path, path) do
    app = Path.join(build_path, path)
    wildcard = Path.join([build_path, path, "*"])
    children = Path.wildcard(wildcard)

    for child <- children do
      case File.read_link(child) do
        {:ok, link} ->
          real =
            case Path.type(link) do
              :absolute -> link
              _ -> Path.join(app, link)
            end
            |> Path.expand()

          save = "#{child}.saved"
          File.write!(save, real)

          File.rm_rf!(child)
          File.mkdir!(child)
          File.cp_r!(real, child)

        _ ->
          nil
      end
    end
  end

  def restore_links(build_path, path) do
    wildcard = Path.join([build_path, path, "*.saved"])
    children = Path.wildcard(wildcard)

    for child <- children do
      real = File.read!(child)
      link = String.trim_trailing(child, ".saved")
      File.rm_rf!(link)
      File.ln_s!(real, link)
      File.rm_rf!(child)
    end
  end
end
