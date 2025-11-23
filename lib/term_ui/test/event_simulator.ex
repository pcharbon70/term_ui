defmodule TermUI.Test.EventSimulator do
  @moduledoc """
  Event simulation for testing TUI components.

  Provides functions to create synthetic events for testing without
  actual terminal input. Events can be injected into components or
  test harnesses.

  ## Usage

      # Simulate key press
      event = EventSimulator.simulate_key(:enter)
      event = EventSimulator.simulate_key(:a, char: "a")
      event = EventSimulator.simulate_key(:c, modifiers: [:ctrl])

      # Simulate mouse click
      event = EventSimulator.simulate_click(10, 20)
      event = EventSimulator.simulate_click(10, 20, :right)

      # Simulate typing a string
      events = EventSimulator.simulate_type("Hello")

      # Simulate sequence of keys
      events = EventSimulator.simulate_sequence([:tab, :tab, :enter])
  """

  alias TermUI.Event
  alias TermUI.Event.Focus
  alias TermUI.Event.Key
  alias TermUI.Event.Mouse
  alias TermUI.Event.Paste
  alias TermUI.Event.Resize

  @doc """
  Simulates a key press event.

  ## Options

  - `:char` - Character produced by key (e.g., "a" for :a key)
  - `:modifiers` - List of modifiers ([:ctrl], [:shift], [:alt], etc.)
  - `:timestamp` - Event timestamp (defaults to current time)

  ## Examples

      EventSimulator.simulate_key(:enter)
      EventSimulator.simulate_key(:a, char: "a")
      EventSimulator.simulate_key(:c, modifiers: [:ctrl])
  """
  @spec simulate_key(atom(), keyword()) :: Key.t()
  def simulate_key(key, opts \\ []) do
    Event.key(key, opts)
  end

  @doc """
  Simulates a mouse click event.

  ## Examples

      EventSimulator.simulate_click(10, 20)
      EventSimulator.simulate_click(10, 20, :right)
      EventSimulator.simulate_click(10, 20, :left, modifiers: [:ctrl])
  """
  @spec simulate_click(integer(), integer(), Mouse.button(), keyword()) :: Mouse.t()
  def simulate_click(x, y, button \\ :left, opts \\ []) do
    Event.mouse(:click, button, x, y, opts)
  end

  @doc """
  Simulates a mouse double-click event.
  """
  @spec simulate_double_click(integer(), integer(), Mouse.button(), keyword()) :: Mouse.t()
  def simulate_double_click(x, y, button \\ :left, opts \\ []) do
    Event.mouse(:double_click, button, x, y, opts)
  end

  @doc """
  Simulates a mouse move event.

  ## Examples

      EventSimulator.simulate_move(15, 25)
  """
  @spec simulate_move(integer(), integer(), keyword()) :: Mouse.t()
  def simulate_move(x, y, opts \\ []) do
    Event.mouse(:move, nil, x, y, opts)
  end

  @doc """
  Simulates a mouse drag event.
  """
  @spec simulate_drag(integer(), integer(), Mouse.button(), keyword()) :: Mouse.t()
  def simulate_drag(x, y, button \\ :left, opts \\ []) do
    Event.mouse(:drag, button, x, y, opts)
  end

  @doc """
  Simulates a scroll up event.
  """
  @spec simulate_scroll_up(integer(), integer(), keyword()) :: Mouse.t()
  def simulate_scroll_up(x, y, opts \\ []) do
    Event.mouse(:scroll_up, nil, x, y, opts)
  end

  @doc """
  Simulates a scroll down event.
  """
  @spec simulate_scroll_down(integer(), integer(), keyword()) :: Mouse.t()
  def simulate_scroll_down(x, y, opts \\ []) do
    Event.mouse(:scroll_down, nil, x, y, opts)
  end

  @doc """
  Simulates typing a string.

  Returns a list of key events, one for each character.

  ## Examples

      events = EventSimulator.simulate_type("Hello")
      length(events)
      # => 5
  """
  @spec simulate_type(String.t(), keyword()) :: [Key.t()]
  def simulate_type(string, opts \\ []) when is_binary(string) do
    string
    |> String.graphemes()
    |> Enum.map(fn char ->
      key = char_to_key(char)
      modifiers = if needs_shift?(char), do: [:shift], else: []
      base_modifiers = Keyword.get(opts, :modifiers, [])
      Event.key(key, char: char, modifiers: base_modifiers ++ modifiers)
    end)
  end

  @doc """
  Simulates a sequence of key presses.

  Each element can be an atom (key name) or {key, opts} tuple.

  ## Examples

      events = EventSimulator.simulate_sequence([:tab, :tab, :enter])
      events = EventSimulator.simulate_sequence([
        {:a, char: "a"},
        :tab,
        :enter
      ])
  """
  @spec simulate_sequence([atom() | {atom(), keyword()}]) :: [Key.t()]
  def simulate_sequence(keys) when is_list(keys) do
    Enum.map(keys, fn
      {key, opts} -> Event.key(key, opts)
      key when is_atom(key) -> Event.key(key)
    end)
  end

  @doc """
  Simulates a focus gained event.
  """
  @spec simulate_focus_gained(keyword()) :: Focus.t()
  def simulate_focus_gained(opts \\ []) do
    Event.focus(:gained, opts)
  end

  @doc """
  Simulates a focus lost event.
  """
  @spec simulate_focus_lost(keyword()) :: Focus.t()
  def simulate_focus_lost(opts \\ []) do
    Event.focus(:lost, opts)
  end

  @doc """
  Simulates a terminal resize event.
  """
  @spec simulate_resize(pos_integer(), pos_integer(), keyword()) :: Resize.t()
  def simulate_resize(width, height, opts \\ []) do
    Event.resize(width, height, opts)
  end

  @doc """
  Simulates a paste event.
  """
  @spec simulate_paste(String.t(), keyword()) :: Paste.t()
  def simulate_paste(content, opts \\ []) do
    Event.paste(content, opts)
  end

  @doc """
  Simulates common keyboard shortcuts.

  ## Examples

      EventSimulator.simulate_shortcut(:copy)   # Ctrl+C
      EventSimulator.simulate_shortcut(:paste)  # Ctrl+V
      EventSimulator.simulate_shortcut(:save)   # Ctrl+S
      EventSimulator.simulate_shortcut(:quit)   # Ctrl+Q
  """
  @spec simulate_shortcut(atom()) :: Key.t()
  def simulate_shortcut(:copy), do: Event.key(:c, modifiers: [:ctrl])
  def simulate_shortcut(:paste), do: Event.key(:v, modifiers: [:ctrl])
  def simulate_shortcut(:cut), do: Event.key(:x, modifiers: [:ctrl])
  def simulate_shortcut(:save), do: Event.key(:s, modifiers: [:ctrl])
  def simulate_shortcut(:quit), do: Event.key(:q, modifiers: [:ctrl])
  def simulate_shortcut(:undo), do: Event.key(:z, modifiers: [:ctrl])
  def simulate_shortcut(:redo), do: Event.key(:z, modifiers: [:ctrl, :shift])
  def simulate_shortcut(:select_all), do: Event.key(:a, modifiers: [:ctrl])

  @doc """
  Simulates pressing a function key.

  ## Examples

      EventSimulator.simulate_function_key(1)  # F1
      EventSimulator.simulate_function_key(12) # F12
  """
  @spec simulate_function_key(1..12) :: Key.t()
  def simulate_function_key(n) when n >= 1 and n <= 12 do
    key = String.to_atom("f#{n}")
    Event.key(key)
  end

  @doc """
  Simulates navigation keys.

  ## Examples

      EventSimulator.simulate_navigation(:up)
      EventSimulator.simulate_navigation(:page_down)
      EventSimulator.simulate_navigation(:home)
  """
  @spec simulate_navigation(atom(), keyword()) :: Key.t()
  def simulate_navigation(direction, opts \\ [])
      when direction in [:up, :down, :left, :right, :home, :end, :page_up, :page_down] do
    Event.key(direction, opts)
  end

  # Private helpers

  defp char_to_key(char) do
    cond do
      char == " " -> :space
      char == "\t" -> :tab
      char == "\n" -> :enter
      char =~ ~r/^[a-z]$/ -> String.to_atom(char)
      char =~ ~r/^[A-Z]$/ -> String.to_atom(String.downcase(char))
      char =~ ~r/^[0-9]$/ -> String.to_atom(char)
      true -> :char
    end
  end

  defp needs_shift?(char) do
    char =~ ~r/^[A-Z!@#$%^&*()_+{}|:"<>?~]$/
  end
end
