defmodule LogViewer.MixProject do
  use Mix.Project

  def project do
    [
      app: :log_viewer,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LogViewer.Application, []}
    ]
  end

  defp deps do
    [
      {:term_ui, path: "../.."}
    ]
  end
end
