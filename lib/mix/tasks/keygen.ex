defmodule Mix.Tasks.Dpi.Keygen do
  use Mix.Task

  @shortdoc "Generate RSA key in PEM format"

  def run(_args) do
    key_pair()
  end

  def key_pair(bits \\ 4096) do
    {:RSAPrivateKey, _, modulus, publicExponent, _, _, _, _exponent1, _, _, _otherPrimeInfos} =
      rsa_private_key = :public_key.generate_key({:rsa, bits, 65537})

    pem_entry = :public_key.pem_entry_encode(:RSAPrivateKey, rsa_private_key)
    private_key = :public_key.pem_encode([pem_entry])

    rsa_public_key = {:RSAPublicKey, modulus, publicExponent}
    public_key = :ssh_file.encode([{rsa_public_key, []}], :openssh_key)

    IO.puts(~s/PUBLIC KEY:\n\n#{public_key}\n\nPRIVATE KEY\n\n#{private_key}/)
  end
end
