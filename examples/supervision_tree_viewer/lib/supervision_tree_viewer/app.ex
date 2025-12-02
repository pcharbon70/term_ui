defmodule SupervisionTreeViewerExample.App do
  @moduledoc """
  Example application demonstrating the SupervisionTreeViewer widget.

  This example shows:
  - Live supervision tree visualization
  - Process status indicators (running/restarting/terminated)
  - Supervisor strategy display (1:1, 1:*, 1:→)
  - Process info panel
  - Restart/terminate controls

  ## Controls

  - Up/Down: Navigate tree
  - Left: Collapse or move to parent
  - Right: Expand or move to first child
  - Enter: Toggle expand/collapse
  - i: Show process info panel
  - r: Restart selected process (with confirmation)
  - k: Terminate selected process (with confirmation)
  - R: Refresh tree
  - /: Filter by name
  - Escape: Clear filter/close panel
  - q: Quit
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Widgets.SupervisionTreeViewer
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  @impl true
  def init(_args) do
    # Start with the example application's sample tree
    root = SupervisionTreeViewerExample.SampleTree

    props =
      SupervisionTreeViewer.new(
        root: root,
        update_interval: 2000,
        auto_expand: true
      )

    {:ok, viewer_state} = SupervisionTreeViewer.init(props)

    %{
      viewer_state: viewer_state,
      message: "SupervisionTreeViewer Example - Press 'i' for process info"
    }
  end

  @doc """
  Convert events to messages.
  """
  @impl true
  def event_to_msg(%Event.Key{char: "q"}, %{viewer_state: %{filter_input: nil}}) do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: key}, _state)
      when key in [:up, :down, :left, :right, :page_up, :page_down, :home, :end] do
    {:msg, {:viewer_event, %Event.Key{key: key}}}
  end

  def event_to_msg(%Event.Key{key: :enter}, _state) do
    {:msg, {:viewer_event, %Event.Key{key: :enter}}}
  end

  def event_to_msg(%Event.Key{char: "i"}, _state) do
    {:msg, {:viewer_event, %Event.Key{char: "i"}}}
  end

  def event_to_msg(%Event.Key{char: "R"}, _state) do
    {:msg, :refresh_tree}
  end

  def event_to_msg(%Event.Key{char: "r"}, %{viewer_state: %{filter_input: nil}}) do
    {:msg, {:viewer_event, %Event.Key{char: "r"}}}
  end

  def event_to_msg(%Event.Key{char: "k"}, %{viewer_state: %{filter_input: nil}}) do
    {:msg, {:viewer_event, %Event.Key{char: "k"}}}
  end

  def event_to_msg(%Event.Key{char: "y"}, %{viewer_state: %{pending_action: action}})
      when action != nil do
    {:msg, {:viewer_event, %Event.Key{char: "y"}}}
  end

  def event_to_msg(%Event.Key{char: "n"}, %{viewer_state: %{pending_action: action}})
      when action != nil do
    {:msg, {:viewer_event, %Event.Key{char: "n"}}}
  end

  def event_to_msg(%Event.Key{char: "/"}, %{viewer_state: %{filter_input: nil}}) do
    {:msg, {:viewer_event, %Event.Key{char: "/"}}}
  end

  def event_to_msg(%Event.Key{char: char}, %{viewer_state: %{filter_input: input}})
      when input != nil and char != nil do
    {:msg, {:viewer_event, %Event.Key{char: char}}}
  end

  def event_to_msg(%Event.Key{key: :backspace}, %{viewer_state: %{filter_input: input}})
      when input != nil do
    {:msg, {:viewer_event, %Event.Key{key: :backspace}}}
  end

  def event_to_msg(%Event.Key{key: :escape}, _state) do
    {:msg, {:viewer_event, %Event.Key{key: :escape}}}
  end

  def event_to_msg(_event, _state) do
    :ignore
  end

  @doc """
  Update state based on messages.
  """
  @impl true
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:refresh_tree, state) do
    {:ok, viewer_state} = SupervisionTreeViewer.refresh(state.viewer_state)
    {%{state | viewer_state: viewer_state, message: "Tree refreshed"}, []}
  end

  def update({:viewer_event, event}, state) do
    {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, state.viewer_state)

    # Update message based on viewer state changes
    message =
      cond do
        viewer_state.show_info != state.viewer_state.show_info ->
          if viewer_state.show_info, do: "Info panel opened", else: "Info panel closed"

        viewer_state.pending_action != state.viewer_state.pending_action and
            viewer_state.pending_action == nil ->
          "Action completed"

        true ->
          state.message
      end

    {%{state | viewer_state: viewer_state, message: message}, []}
  end

  def update(_msg, state) do
    {state, []}
  end

  @doc """
  Render the application view.
  """
  @impl true
  def view(model) do
    area = %{x: 0, y: 0, width: 100, height: 25}
    viewer_view = SupervisionTreeViewer.render(model.viewer_state, area)

    stack(:vertical, [
      text("SupervisionTreeViewer Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(model.message, Style.new(fg: :yellow)),
      text("", nil),
      viewer_view,
      text("", nil),
      text("[q] Quit", Style.new(fg: :white, attrs: [:dim]))
    ])
  end

  # ----------------------------------------------------------------------------
  # Run
  # ----------------------------------------------------------------------------

  @doc """
  Run the supervision tree viewer example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
