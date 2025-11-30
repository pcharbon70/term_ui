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

  alias TermUI.Widgets.SupervisionTreeViewer
  alias TermUI.Renderer.Style

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

    model = %{
      viewer_state: viewer_state,
      message: "SupervisionTreeViewer Example - Press 'i' for process info"
    }

    {:ok, model}
  end

  @impl true
  def update(msg, model) do
    case msg do
      # Navigation
      {:key, %{key: key}}
      when key in [:up, :down, :left, :right, :page_up, :page_down, :home, :end] ->
        event = %TermUI.Event.Key{key: key}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Enter - expand/collapse
      {:key, %{key: :enter}} ->
        event = %TermUI.Event.Key{key: :enter}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Info panel
      {:key, %{char: "i"}} ->
        event = %TermUI.Event.Key{char: "i"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)

        msg =
          if viewer_state.show_info do
            "Info panel opened"
          else
            "Info panel closed"
          end

        {:ok, %{model | viewer_state: viewer_state, message: msg}}

      # Refresh
      {:key, %{char: "R"}} ->
        {:ok, viewer_state} = SupervisionTreeViewer.refresh(model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state, message: "Tree refreshed"}}

      # Restart process
      {:key, %{char: "r"}} when model.viewer_state.filter_input == nil ->
        event = %TermUI.Event.Key{char: "r"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Terminate process
      {:key, %{char: "k"}} when model.viewer_state.filter_input == nil ->
        event = %TermUI.Event.Key{char: "k"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Confirm action
      {:key, %{char: "y"}} when model.viewer_state.pending_action != nil ->
        event = %TermUI.Event.Key{char: "y"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state, message: "Action completed"}}

      # Cancel action
      {:key, %{char: "n"}} when model.viewer_state.pending_action != nil ->
        event = %TermUI.Event.Key{char: "n"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state, message: "Action cancelled"}}

      # Filter
      {:key, %{char: "/"}} when model.viewer_state.filter_input == nil ->
        event = %TermUI.Event.Key{char: "/"}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Filter input
      {:key, %{char: char}}
      when model.viewer_state.filter_input != nil and char != nil ->
        event = %TermUI.Event.Key{char: char}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      {:key, %{key: :backspace}} when model.viewer_state.filter_input != nil ->
        event = %TermUI.Event.Key{key: :backspace}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Escape
      {:key, %{key: :escape}} ->
        event = %TermUI.Event.Key{key: :escape}
        {:ok, viewer_state} = SupervisionTreeViewer.handle_event(event, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      # Quit
      {:key, %{char: "q"}} when model.viewer_state.filter_input == nil ->
        {:stop, :normal}

      # Refresh timer
      :refresh ->
        {:ok, viewer_state} = SupervisionTreeViewer.handle_info(:refresh, model.viewer_state)
        {:ok, %{model | viewer_state: viewer_state}}

      _ ->
        {:ok, model}
    end
  end

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
end
