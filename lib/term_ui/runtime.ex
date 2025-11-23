defmodule TermUI.Runtime do
  @moduledoc """
  The central runtime orchestrator for TermUI applications.

  The runtime implements The Elm Architecture dispatch loop:
  1. Receive event from terminal
  2. Route to appropriate component
  3. Call component's event_to_msg
  4. Call component's update with message
  5. Collect commands from update
  6. Mark component dirty
  7. On render timer, call view and render

  ## Usage

      # Start with a root component
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root)

      # Send events (usually from terminal input)
      Runtime.send_event(runtime, Event.key(:enter))

      # Shutdown gracefully
      Runtime.shutdown(runtime)
  """

  use GenServer

  alias TermUI.Elm
  alias TermUI.Event
  alias TermUI.MessageQueue
  alias TermUI.Renderer.BufferManager
  alias TermUI.Renderer.Diff
  alias TermUI.Renderer.SequenceBuffer
  alias TermUI.Runtime.NodeRenderer
  alias TermUI.Runtime.State
  alias TermUI.Terminal

  @type option ::
          {:root, module()}
          | {:name, GenServer.name()}
          | {:render_interval, pos_integer()}

  # Default render interval in milliseconds (~60 FPS)
  @default_render_interval 16

  # --- Public API ---

  @doc """
  Starts the runtime with the given options.

  ## Options

  - `:root` - The root component module (required)
  - `:name` - GenServer name (optional)
  - `:render_interval` - Milliseconds between renders (default: 16)
  """
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Sends an event to the runtime for processing.
  """
  @spec send_event(GenServer.server(), Event.t()) :: :ok
  def send_event(runtime, event) do
    GenServer.cast(runtime, {:event, event})
  end

  @doc """
  Sends a message directly to a component.
  """
  @spec send_message(GenServer.server(), term(), term()) :: :ok
  def send_message(runtime, component_id, message) do
    GenServer.cast(runtime, {:message, component_id, message})
  end

  @doc """
  Delivers a command result back to the runtime.
  """
  @spec command_result(GenServer.server(), term(), term(), term()) :: :ok
  def command_result(runtime, component_id, command_id, result) do
    GenServer.cast(runtime, {:command_result, component_id, command_id, result})
  end

  @doc """
  Initiates graceful shutdown of the runtime.
  """
  @spec shutdown(GenServer.server()) :: :ok
  def shutdown(runtime) do
    GenServer.cast(runtime, :shutdown)
  end

  @doc """
  Gets the current runtime state (for testing/debugging).
  """
  @spec get_state(GenServer.server()) :: State.t()
  def get_state(runtime) do
    GenServer.call(runtime, :get_state)
  end

  @doc """
  Forces an immediate render (bypassing framerate limiter).
  """
  @spec force_render(GenServer.server()) :: :ok
  def force_render(runtime) do
    GenServer.cast(runtime, :force_render)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    root_module = Keyword.fetch!(opts, :root)
    render_interval = Keyword.get(opts, :render_interval, @default_render_interval)
    skip_terminal = Keyword.get(opts, :skip_terminal, false)

    # Initialize terminal and buffer manager (unless skipped for tests)
    {terminal_started, buffer_manager, dimensions} =
      if skip_terminal do
        {false, nil, nil}
      else
        initialize_terminal()
      end

    # Initialize root component state
    root_state =
      if function_exported?(root_module, :init, 1) do
        root_module.init(opts)
      else
        %{}
      end

    state = %State{
      root_module: root_module,
      root_state: root_state,
      message_queue: MessageQueue.new(),
      render_interval: render_interval,
      # Initial render needed
      dirty: true,
      focused_component: :root,
      components: %{root: %{module: root_module, state: root_state}},
      pending_commands: %{},
      shutting_down: false,
      terminal_started: terminal_started,
      buffer_manager: buffer_manager,
      dimensions: dimensions
    }

    # Schedule first render
    schedule_render(render_interval)

    {:ok, state}
  end

  defp initialize_terminal do
    # Start Terminal GenServer
    case Terminal.start_link() do
      {:ok, _pid} ->
        setup_terminal_and_buffers()

      {:error, {:already_started, _pid}} ->
        setup_terminal_and_buffers()

      {:error, _reason} ->
        # Terminal not available (e.g., not a TTY)
        {false, nil, nil}
    end
  end

  defp setup_terminal_and_buffers do
    # Enable raw mode and alternate screen
    Terminal.enable_raw_mode()
    Terminal.enter_alternate_screen()
    Terminal.hide_cursor()

    # Get terminal dimensions
    {rows, cols} =
      case Terminal.get_terminal_size() do
        {:ok, {rows, cols}} -> {rows, cols}
        {:error, _reason} -> {24, 80}
      end

    # Start BufferManager with terminal dimensions
    buffer_pid =
      case BufferManager.start_link(rows: rows, cols: cols) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    {true, buffer_pid, {cols, rows}}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    if state.shutting_down do
      {:noreply, state}
    else
      state = dispatch_event(event, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:message, component_id, message}, state) do
    if state.shutting_down do
      {:noreply, state}
    else
      state = enqueue_message(component_id, message, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:command_result, component_id, command_id, result}, state) do
    state = handle_command_result(component_id, command_id, result, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:shutdown, state) do
    state = initiate_shutdown(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:force_render, state) do
    state = do_render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:render, state) do
    state = process_render_tick(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Command task completed (handled via command_result)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Ensure clean shutdown
    if not state.shutting_down do
      do_shutdown(state)
    end

    # Restore terminal
    if state.terminal_started do
      Terminal.restore()
    end

    :ok
  end

  # --- Event Dispatch ---

  defp dispatch_event(%Event.Key{} = event, state) do
    # Keyboard events go to focused component
    dispatch_to_component(state.focused_component, event, state)
  end

  defp dispatch_event(%Event.Mouse{} = event, state) do
    # Mouse events go to component at position
    # For now, just send to root (spatial index will be added later)
    dispatch_to_component(:root, event, state)
  end

  defp dispatch_event(%Event.Resize{} = event, state) do
    # Resize broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(%Event.Focus{} = event, state) do
    # Focus broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(%Event.Paste{} = event, state) do
    # Paste goes to focused component
    dispatch_to_component(state.focused_component, event, state)
  end

  defp dispatch_event(%Event.Tick{} = event, state) do
    # Tick broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(_event, state) do
    # Unknown event type, ignore
    state
  end

  defp dispatch_to_component(component_id, event, state) do
    case Map.get(state.components, component_id) do
      nil ->
        state

      %{module: module, state: component_state} ->
        # Transform event to message
        case module.event_to_msg(event, component_state) do
          {:msg, message} ->
            enqueue_message(component_id, message, state)

          :ignore ->
            state

          :propagate ->
            # Would propagate to parent, for now just ignore
            state
        end
    end
  end

  defp broadcast_event(event, state) do
    Enum.reduce(state.components, state, fn {component_id, _}, acc ->
      dispatch_to_component(component_id, event, acc)
    end)
  end

  # --- Message Processing ---

  defp enqueue_message(component_id, message, state) do
    queue = MessageQueue.enqueue(state.message_queue, {component_id, message})
    %{state | message_queue: queue}
  end

  defp process_messages(state) do
    {messages, queue} = MessageQueue.flush(state.message_queue)

    {state, commands} =
      Enum.reduce(messages, {%{state | message_queue: queue}, []}, fn {component_id, message},
                                                                      {acc_state, acc_cmds} ->
        {new_state, cmds} = process_message(component_id, message, acc_state)
        {new_state, acc_cmds ++ cmds}
      end)

    # Execute collected commands
    state = execute_commands(commands, state)

    state
  end

  defp process_message(component_id, message, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {state, []}

      %{module: module, state: component_state} ->
        # Call update function
        result = module.update(message, component_state)
        {new_component_state, commands} = Elm.normalize_update_result(result, component_state)

        # Update component state
        components =
          Map.update!(state.components, component_id, fn comp ->
            %{comp | state: new_component_state}
          end)

        # Mark dirty if state changed
        dirty = state.dirty or new_component_state != component_state

        # Update root_state if this is root
        state =
          if component_id == :root do
            %{state | root_state: new_component_state, components: components, dirty: dirty}
          else
            %{state | components: components, dirty: dirty}
          end

        # Tag commands with component_id
        tagged_commands = Enum.map(commands, fn cmd -> {component_id, cmd} end)

        {state, tagged_commands}
    end
  end

  # --- Command Execution ---

  defp execute_commands([], state), do: state

  defp execute_commands(commands, state) do
    # For now, just track pending commands
    # Actual execution will be implemented in 5.3
    pending =
      Enum.reduce(commands, state.pending_commands, fn {component_id, cmd}, acc ->
        command_id = make_ref()
        Map.put(acc, command_id, %{component_id: component_id, command: cmd})
      end)

    %{state | pending_commands: pending}
  end

  defp handle_command_result(component_id, command_id, result, state) do
    # Remove from pending
    pending = Map.delete(state.pending_commands, command_id)
    state = %{state | pending_commands: pending}

    # Send result as message to component
    enqueue_message(component_id, result, state)
  end

  # --- Rendering ---

  defp schedule_render(interval) do
    Process.send_after(self(), :render, interval)
  end

  defp process_render_tick(state) do
    # Process any pending messages
    state = process_messages(state)

    # Render if dirty
    state =
      if state.dirty and not state.shutting_down do
        do_render(state)
      else
        state
      end

    # Schedule next render unless shutting down
    unless state.shutting_down do
      schedule_render(state.render_interval)
    end

    state
  end

  defp do_render(state) do
    # Skip rendering if terminal not available
    if not state.terminal_started do
      %{state | dirty: false}
    else
      # Call view on root component
      %{module: module, state: component_state} = Map.get(state.components, :root)
      render_tree = module.view(component_state)

      # Clear current buffer
      BufferManager.clear_current(state.buffer_manager)

      # Render tree to buffer
      NodeRenderer.render_to_buffer(render_tree, state.buffer_manager)

      # Get buffers for diffing
      current = BufferManager.get_current_buffer(state.buffer_manager)
      previous = BufferManager.get_previous_buffer(state.buffer_manager)

      # Compute diff operations
      operations = Diff.diff(current, previous)

      # Render operations to terminal
      render_operations(operations)

      # Swap buffers
      BufferManager.swap_buffers(state.buffer_manager)

      %{state | dirty: false}
    end
  end

  defp render_operations([]), do: :ok

  defp render_operations(operations) do
    seq_buffer = SequenceBuffer.new()

    seq_buffer =
      Enum.reduce(operations, seq_buffer, fn op, buf ->
        apply_operation(op, buf)
      end)

    # Flush to terminal
    {output, _buf} = SequenceBuffer.flush(seq_buffer)
    IO.write(output)
  end

  defp apply_operation({:move, row, col}, buffer) do
    # ANSI cursor position: ESC[row;colH
    seq = "\e[#{row};#{col}H"
    SequenceBuffer.append!(buffer, seq)
  end

  defp apply_operation({:style, style}, buffer) do
    SequenceBuffer.append_style(buffer, style)
  end

  defp apply_operation({:text, text}, buffer) do
    SequenceBuffer.append!(buffer, text)
  end

  defp apply_operation(:reset, buffer) do
    SequenceBuffer.append!(buffer, "\e[0m")
  end

  # --- Shutdown ---

  defp initiate_shutdown(state) do
    %{state | shutting_down: true}
    |> do_shutdown()
  end

  defp do_shutdown(state) do
    # Wait for pending commands to complete (with timeout)
    # For now, just clear them
    state = %{state | pending_commands: %{}}

    # Terminate components (leaf to root)
    # For now, just clear components
    state = %{state | components: %{}}

    state
  end
end
