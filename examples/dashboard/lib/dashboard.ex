defmodule Dashboard do
  @moduledoc """
  A system monitoring dashboard example for TermUI.

  This application demonstrates:
  - Multiple widget types (gauges, charts, tables)
  - Layout system with nested constraints
  - Real-time updates using commands
  - Keyboard navigation and shortcuts
  - Theme switching

  ## Running

      cd examples/dashboard
      mix deps.get
      mix run --no-halt

  ## Controls

  - `q` - Quit the application
  - `r` - Force refresh data
  - `t` - Toggle theme (dark/light)
  - `Tab` - Navigate between focusable widgets
  - `↑/↓` - Scroll process table
  """

  @doc """
  Starts the dashboard interactively, blocking until the user quits.

  This is the main entry point for both IEx and standalone use. It blocks
  the calling process to take over terminal input - this is required for
  keyboard controls to work when running from IEx.

  ## From IEx

      iex> Dashboard.start()
      # Dashboard takes over terminal, press Q to quit

  ## From command line

      mix run -e "Dashboard.start()"
  """
  def start do
    TermUI.Runtime.run(root: Dashboard.App)
  end

  @doc """
  Starts the dashboard as a linked process (non-blocking).

  Returns `{:ok, pid}` immediately. Useful for embedding in supervision
  trees or programmatic control. Note: keyboard input will NOT work when
  called from IEx because IEx's prompt competes for terminal input.

  For interactive use from IEx, use `start/0` instead.
  """
  def start_link do
    TermUI.Runtime.start_link(root: Dashboard.App)
  end
end
