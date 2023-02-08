defmodule Mix.Tasks.Dpi.Sign do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Signs the application"

  def run(args) do
    {app_name, dpi, path} =
      case args do
        [app_name, path] ->
          dpi = Dpi.basic_config(false)
          {app_name |> String.to_atom(), dpi, path}

        [] ->
          dpi = Dpi.basic_config(true)
          {dpi.name, dpi, Path.join("priv", "signature")}

        _ ->
          Mix.raise("usage: mix dpi.sign <app_name> <filename>")
      end

    Mix.shell().info("Signing for: #{Dpi.runtime_id(dpi)}")
    privkey = load_privkey()

    # nat networking requires to use IP in host
    # use bid to sign when IP is used instead of hostname
    hostname =
      case dpi.host do
        "localhost" -> dpi.runtime
        "127.0.0.1" -> dpi.runtime
        _ -> dpi.bid |> String.replace_suffix(".local", "")
      end

    signature = sign(hostname, app_name, privkey)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, signature)
  end

  defp load_privkey() do
    path = Path.join(Dpi.user_dir(), "id_rsa")
    pem = File.read!(path)
    [privkey] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(privkey)
  end

  defp sign(hostname, appname, privkey) do
    msg = "#{hostname}:#{appname}"
    :public_key.sign(msg, :sha512, privkey) |> Base.encode64()
  end
end
