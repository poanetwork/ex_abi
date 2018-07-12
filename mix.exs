defmodule ABI.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_abi,
     version: "0.1.13",
      elixir: "~> 1.6",
      description: "Ethereum's ABI Interface",
      package: [
        maintainers: ["Ayrat Badykov"],
        licenses: ["GPL-3.0"],
        links: %{"GitHub" => "https://github.com/poanetwork/ex_abi"}
      ],
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:poison, "~> 3.1", only: [:dev, :test]},
      {:exth_crypto, "~> 0.1.4"}
    ]
  end
end
