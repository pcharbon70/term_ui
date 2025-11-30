defmodule StreamWidgetExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :stream_widget_example,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {StreamWidgetExample.Application, []}
    ]
  end

  defp deps do
    [
      {:term_ui, path: "../.."},
      {:gen_stage, "~> 1.2"}
    ]
  end
end
