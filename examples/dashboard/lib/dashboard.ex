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
  Starts the dashboard in non-blocking mode. Returns immediately with {:ok, pid}.
  Useful for development in IEx.
  """
  def start do
    TermUI.Runtime.start_link(root: Dashboard.App)
  end

  @doc """
  Runs the dashboard in blocking mode. Takes over the terminal and blocks
  until the user quits. This is the main entry point for running as a standalone app.
  """
  def run do
    TermUI.Runtime.run(root: Dashboard.App)
  end
end
