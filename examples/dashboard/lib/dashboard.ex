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

  def start do
    TermUI.Runtime.start_link(root: Dashboard.App)
  end
end
