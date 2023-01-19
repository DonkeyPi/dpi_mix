defmodule Mix.Tasks.Dpi.Sign do
  use Mix.Task
  alias Mix.Tasks.Dpi

  @shortdoc "Signs the application"

  def run(_args) do
    dpi = Dpi.basic_config(true)
    Mix.shell().info("Signing for: #{Dpi.runtime_id(dpi)}")
    privkey = load_privkey()

    hostname =
      case dpi.host do
        "localhost" -> dpi.runtime
        "127.0.0.1" -> dpi.runtime
        _ -> dpi.host
      end

    signature = sign(hostname, dpi.name, privkey)
    File.mkdir_p!("priv")
    path = Path.join("priv", "donkeypi.txt")
    File.write!(path, signature)
  end

  defp load_privkey() do
    home = System.user_home!()
    path = Path.join([home, ".ssh", "donkeypi.pem"])
    pem = File.read!(path)
    [privkey] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(privkey)
  end

  defp sign(hostname, appname, privkey) do
    msg = "#{hostname}:#{appname}"
    :public_key.sign(msg, :sha512, privkey) |> Base.encode64()
  end
end
