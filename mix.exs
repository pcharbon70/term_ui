defmodule TermUI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/pcharbon70/term_ui"

  def project do
    [
      app: :term_ui,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex package
      name: "TermUI",
      description: "A direct-mode Terminal UI framework for Elixir/BEAM",
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),

      # Test coverage
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
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
      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Testing
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      name: "term_ui",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/user/README.md": [filename: "user-guides", title: "User Guides"],
        "guides/user/01-overview.md": [title: "Overview"],
        "guides/user/02-getting-started.md": [title: "Getting Started"],
        "guides/user/03-elm-architecture.md": [title: "The Elm Architecture"],
        "guides/user/04-events.md": [title: "Events"],
        "guides/user/05-styling.md": [title: "Styling"],
        "guides/user/06-layout.md": [title: "Layout"],
        "guides/user/07-widgets.md": [title: "Widgets"],
        "guides/user/08-terminal.md": [title: "Terminal"],
        "guides/user/09-commands.md": [title: "Commands"],
        "guides/developer/README.md": [filename: "developer-guides", title: "Developer Guides"],
        "guides/developer/01-architecture-overview.md": [title: "Architecture Overview"],
        "guides/developer/08-creating-widgets.md": [title: "Creating Widgets"],
        "guides/developer/09-testing-framework.md": [title: "Testing Framework"]
      ],
      groups_for_extras: [
        "User Guides": ~r/guides\/user\/.*/,
        "Developer Guides": ~r/guides\/developer\/.*/
      ],
      groups_for_modules: [
        Core: [
          TermUI,
          TermUI.Elm,
          TermUI.Runtime,
          TermUI.Component,
          TermUI.Event
        ],
        Widgets: ~r/TermUI\.Widgets\..*/,
        Rendering: [
          TermUI.Renderer.Style,
          TermUI.Renderer.Cell,
          TermUI.Renderer.Buffer,
          TermUI.Component.RenderNode
        ],
        Layout: ~r/TermUI\.Layout\..*/,
        Terminal: ~r/TermUI\.Terminal\..*/
      ]
    ]
  end
end
