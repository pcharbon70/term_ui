defmodule SupervisionTreeViewerExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :supervision_tree_viewer_example,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SupervisionTreeViewerExample.Application, []}
    ]
  end

  defp deps do
    [
      {:term_ui, path: "../.."}
    ]
  end
end
