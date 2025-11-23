defmodule TermUI.Widget.Button do
  @moduledoc """
  An interactive button widget.

  Button responds to Enter/Space keys when focused and mouse clicks.
  It displays visual feedback for different states.

  ## Usage

      Button.render(%{
        label: "Submit",
        on_click: fn -> send(self(), :submitted) end
      }, state, area)

  ## Props

  - `:label` - Button text (required)
  - `:on_click` - Callback function invoked on activation
  - `:disabled` - Whether button is disabled (default: `false`)
  - `:style` - Style options
  - `:focused_style` - Style when focused
  - `:pressed_style` - Style when pressed
  """

  use TermUI.StatefulComponent

  alias TermUI.Component.RenderNode
  alias TermUI.Event
  alias TermUI.Renderer.Style

  @doc """
  Initializes the button state.
  """
  @impl true
  def init(props) do
    state = %{
      pressed: false,
      hovered: false,
      disabled: Map.get(props, :disabled, false),
      props: props
    }

    {:ok, state}
  end

  @doc """
  Handles events for the button.
  """
  @impl true
  def handle_event(%Event.Key{key: key}, state) when key in [:enter, :space] do
    if state.disabled do
      {:ok, state}
    else
      {:ok, %{state | pressed: true}, [{:send, self(), :click}]}
    end
  end

  def handle_event(%Event.Mouse{action: :click}, state) do
    if state.disabled do
      {:ok, state}
    else
      {:ok, %{state | pressed: true}, [{:send, self(), :click}]}
    end
  end

  def handle_event(%Event.Mouse{action: :press}, state) do
    if state.disabled do
      {:ok, state}
    else
      {:ok, %{state | pressed: true}}
    end
  end

  def handle_event(%Event.Mouse{action: :release}, state) do
    {:ok, %{state | pressed: false}}
  end

  def handle_event(%Event.Focus{action: :gained}, state) do
    {:ok, state}
  end

  def handle_event(%Event.Focus{action: :lost}, state) do
    {:ok, %{state | pressed: false}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @doc """
  Handles messages to the button.
  """
  @impl true
  def handle_info(:click, state) do
    # Invoke on_click callback
    props = state.props
    on_click = Map.get(props, :on_click)

    if is_function(on_click, 0) do
      on_click.()
    end

    {:ok, %{state | pressed: false}}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc """
  Renders the button.
  """
  @impl true
  def render(state, area) do
    props = state.props
    label = Map.get(props, :label, "Button")
    disabled = state.disabled

    style = get_style(props, state)

    # Center the label
    text = center_text(label, area.width)

    cells =
      text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.filter(fn {_char, x} -> x < area.width end)
      |> Enum.map(fn {char, x} ->
        cell_style =
          if disabled do
            Style.new(fg: :bright_black)
          else
            style
          end

        positioned_cell(x, 0, char, cell_style)
      end)

    RenderNode.cells(cells)
  end

  # Private Functions

  defp get_style(props, state) do
    if state.pressed do
      build_style(Map.get(props, :pressed_style, %{fg: :black, bg: :white}))
    else
      build_style(Map.get(props, :style, %{}))
    end
  end

  defp build_style(opts) when is_map(opts) do
    style_list =
      opts
      |> Enum.map(fn
        {:fg, color} -> {:fg, color}
        {:bg, color} -> {:bg, color}
        {:bold, true} -> {:attrs, [:bold]}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Style.new(style_list)
  end

  defp build_style(_), do: Style.new()

  defp center_text(text, width) do
    len = String.length(text)

    if len >= width do
      String.slice(text, 0, width)
    else
      padding = div(width - len, 2)
      text |> String.pad_leading(len + padding) |> String.pad_trailing(width)
    end
  end
end
