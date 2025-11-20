defmodule TermUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :term_ui,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A direct-mode Terminal UI framework for Elixir/BEAM",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
