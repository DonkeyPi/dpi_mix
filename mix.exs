defmodule Installer.MixProject do
  use Mix.Project

  def project do
    [
      app: :installer,
      version: "0.1.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
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
