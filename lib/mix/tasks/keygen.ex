defmodule Mix.Tasks.Dpi.Keygen do
  use Mix.Task

  @shortdoc "Generate RSA key in PEM format"

  def run(args) do
    case args do
      [] -> key_pair()
      [name] -> key_pair(name)
      _ -> Mix.raise("use: mix dpi.keygen <filename>")
    end
  end

  @ssh ".ssh"
  @prv Path.join(@ssh, "id_rsa")
  @pub Path.join(@ssh, "id_rsa.pub")

  def key_pair(name \\ nil) do
    {:RSAPrivateKey, _, modulus, publicExponent, _, _, _, _exponent1, _, _, _otherPrimeInfos} =
      rsa_private_key = :public_key.generate_key({:rsa, 4096, 65537})

    pem_entry = :public_key.pem_entry_encode(:RSAPrivateKey, rsa_private_key)
    private_key = :public_key.pem_encode([pem_entry])

    {:ok, hostname} = :inet.gethostname()
    comment = "#{System.get_env("USER")}@#{hostname}"
    rsa_public_key = {:RSAPublicKey, modulus, publicExponent}
    public_key = :ssh_file.encode([{rsa_public_key, [{:comment, comment}]}], :openssh_key)

    if name == nil do
      File.mkdir_p!(@ssh)
      if File.exists?(@prv), do: Mix.raise("Key file exists: #{@prv}")
      if File.exists?(@pub), do: Mix.raise("Key file exists: #{@pub}")
      File.write!(@prv, private_key)
      File.write!(@pub, public_key)
    else
      File.write!("#{name}", private_key)
      File.write!("#{name}.pub", public_key)
    end
  end
end
