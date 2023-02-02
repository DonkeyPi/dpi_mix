defmodule Dpi.Mix.Asdf do
  def path(name, version \\ nil) do
    args =
      case version do
        nil -> ["where", "dpi"]
        version -> ["where", "dpi", version]
      end

    {output, 0} = System.cmd("asdf", args)
    output = output |> String.trim()
    Path.join(output, "#{name}")
  end
end
