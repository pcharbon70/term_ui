defmodule PickList.MixProject do
  use Mix.Project

  def project do
    [
      app: :pick_list,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PickList.Application, []}
    ]
  end

  defp deps do
    [
      {:term_ui, path: "../.."}
    ]
  end
end
