defmodule IExCounter.App do
  @moduledoc """
  Simple counter example for demonstrating IEx compatibility.

  This example demonstrates that TermUI applications work directly
  in IEx with no code changes required.

  ## Running in IEx

  From the project root:

      cd examples/iex_counter
      iex -S mix

  Then in IEx:

      iex> IExCounter.App.run()

  Controls:
  - Up arrow: Increment counter
  - Down arrow: Decrement counter
  - R: Reset counter
  - Q: Quit (returns to IEx prompt)

  ## Running Standalone

      mix termui.run

  ## What Works in IEx

  - Character and navigation input is parsed after the shell delivers it
  - Arrow keys work once the shell delivers them (some terminals require Enter)
  - Terminal state is restored when you quit
  - You return to the IEx prompt ready for next command

  ## IEx Detection

  In your component code, you can detect if running in IEx:

      if TermUI.iex_mode?() do
        # IEx-specific behavior
      end
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    %{
      count: 0,
      mode: :normal
    }
  end

  @impl true
  def event_to_msg(%Event.Key{key: :up}, _state) do
    {:msg, :increment}
  end

  def event_to_msg(%Event.Key{key: :down}, _state) do
    {:msg, :decrement}
  end

  def event_to_msg(%Event.Key{key: "r"}, _state) do
    {:msg, :reset}
  end

  def event_to_msg(%Event.Key{key: "q"}, _state) do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: "Q"}, _state) do
    {:msg, :quit}
  end

  def event_to_msg(_, _state), do: :ignore

  @impl true
  def update(:increment, state) do
    {%{state | count: state.count + 1}, []}
  end

  def update(:decrement, state) do
    {%{state | count: state.count - 1}, []}
  end

  def update(:reset, state) do
    {%{state | count: 0}, []}
  end

  def update(:quit, state) do
    {state, [TermUI.Command.quit()]}
  end

  @impl true
  def view(state) do
    mode_str = if TermUI.iex_mode?(), do: "IEx", else: "Standalone"

    stack(:vertical, [
      # Title
      text("IEx Counter Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Mode indicator
      text("Running in: #{mode_str} mode", Style.new(fg: :bright_black)),
      text("", nil),

      # Counter display
      text("Count: #{state.count}", Style.new(fg: :green, attrs: [:bold])),
      text("", nil),

      # Instructions
      text("Controls:", Style.new(fg: :yellow, attrs: [:bold])),
      text("  ↑/↓ : Increment/Decrement", nil),
      text("  R   : Reset", nil),
      text("  Q   : Quit to IEx prompt", nil)
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the counter application.

  This is the main entry point for running the application.
  Use `TermUI.App.run/1` which provides the proper runtime setup.

  ## Examples

      iex> IExCounter.App.run()
      # ... interact with the TUI app ...
      # Press Q to quit, returns to IEx
      {:ok, :exited_normally}

  """
  def run(opts \\ []) do
    TermUI.App.run(__MODULE__, opts)
  end
end
