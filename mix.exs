defmodule Onartsipac.Mixfile do
  use Mix.Project

  def project do
    [app: :onartsipac,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),

     description: "Saithe9v mib4ahVe AeF9aihi eor5zuSh",
     package: package()
    ]
  end

  defp package do
    [maintainers: ["Thomas Stratmann"],
     licenses: ["MIT"],
     links: %{},
     files: ~w(mix.exs README.md lib)]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:porcelain, "~> 2.0", only: [:dev, :test]}
    ]
  end
end
