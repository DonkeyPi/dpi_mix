defmodule Installer.MixProject do
  use Mix.Project

  # Archives just sets dependencies for the compiler to be aware of.
  # mix archive.install hex nerves_bootstrap
  def project do
    [
      app: :installer,
      version: "0.1.2",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      archives: [nerves_bootstrap: "~> 1.11"],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssh]
    ]
  end

  defp deps do
    []
  end
end
