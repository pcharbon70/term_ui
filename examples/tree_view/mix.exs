defmodule TreeView.MixProject do
  use Mix.Project

  def project do
    [
      app: :tree_view,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TreeView.Application, []}
    ]
  end

  defp deps do
    [
      {:term_ui, path: "../.."}
    ]
  end
end
