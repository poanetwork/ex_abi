defmodule ABI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_abi,
      version: "0.2.1",
      elixir: "~> 1.7",
      description: "Ethereum's ABI Interface",
      package: [
        maintainers: ["Ayrat Badykov"],
        licenses: ["GPL-3.0"],
        links: %{"GitHub" => "https://github.com/poanetwork/ex_abi"}
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
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
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:jason, "~> 1.1", only: [:dev, :test]},
      {:exth_crypto, "~> 0.1.6"},
      {:stream_data, "~> 0.4", only: :test}
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns]
    ]
  end
end
