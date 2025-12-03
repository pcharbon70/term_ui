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
  alias TermUI.Terminal.InputReader

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
  Synchronously waits for all pending events and messages to be processed.

  This is primarily useful for testing to avoid race conditions from
  Process.sleep. It processes all queued messages and returns when complete.

  ## Example

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)  # Wait for both events to be processed
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 2
  """
  @spec sync(GenServer.server(), timeout()) :: :ok
  def sync(runtime, timeout \\ 5000) do
    GenServer.call(runtime, :sync, timeout)
  end

  @doc """
  Forces an immediate render (bypassing framerate limiter).
  """
  @spec force_render(GenServer.server()) :: :ok
  def force_render(runtime) do
    GenServer.cast(runtime, :force_render)
  end

  @doc """
  Starts the runtime and blocks until it shuts down.

  This is the main entry point for running a TUI application. It starts the
  runtime, takes over the terminal, and blocks the calling process until
  the application exits (e.g., user presses quit key).

  ## Options

  Same as `start_link/1`.

  ## Example

      # In your application entry point:
      TermUI.Runtime.run(root: MyApp.Root)
      # This blocks until the app exits
  """
  @spec run([option()]) :: :ok | {:error, term()}
  def run(opts) do
    case start_link(opts) do
      {:ok, runtime} ->
        # Monitor the runtime process and block until it exits
        ref = Process.monitor(runtime)

        receive do
          {:DOWN, ^ref, :process, ^runtime, _reason} ->
            :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    # Trap exits to ensure terminate/2 is called even on crashes
    Process.flag(:trap_exit, true)

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
    root_state = root_module.init(opts)

    # Start input reader and register for resize callbacks if terminal is available
    input_reader =
      if terminal_started do
        {:ok, reader_pid} = InputReader.start_link(target: self())
        Terminal.register_resize_callback(self())
        reader_pid
      else
        nil
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
      dimensions: dimensions,
      input_reader: input_reader
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
    Terminal.enable_mouse_tracking(:all)

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
  def handle_info({:input, event}, state) do
    # Keyboard/mouse input from InputReader
    if state.shutting_down do
      {:noreply, state}
    else
      state = dispatch_event(event, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:terminal_resize, {rows, cols}}, state) do
    # Terminal window was resized
    if state.shutting_down do
      {:noreply, state}
    else
      state = handle_resize(rows, cols, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Command task completed (handled via command_result)
    {:noreply, state}
  end

  @impl true
  def handle_info(:stop_runtime, state) do
    # Stop the GenServer after shutdown cleanup
    {:stop, :normal, state}
  end

  # Catch-all for unknown messages - forward to root module's handle_info if it exists
  @impl true
  def handle_info(msg, state) do
    if function_exported?(state.root_module, :handle_info, 2) do
      case state.root_module.handle_info(msg, state.root_state) do
        {new_root_state, commands} ->
          # Update both root_state and components[:root].state
          components =
            Map.update!(state.components, :root, fn comp ->
              %{comp | state: new_root_state}
            end)

          state = %{state | root_state: new_root_state, components: components, dirty: true}
          state = execute_commands(commands, state)
          {:noreply, state}

        new_root_state ->
          # Support simple return without commands
          # Update both root_state and components[:root].state
          components =
            Map.update!(state.components, :root, fn comp ->
              %{comp | state: new_root_state}
            end)

          {:noreply, %{state | root_state: new_root_state, components: components, dirty: true}}
      end
    else
      # Ignore unknown messages if root module doesn't handle them
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:sync, _from, state) do
    # Process all pending messages synchronously
    state = process_messages(state)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Wrap all cleanup in try/rescue to ensure we attempt all cleanup steps
    # even if some fail

    # Stop input reader first to stop receiving events
    try do
      if state.input_reader do
        InputReader.stop(state.input_reader)
      end
    rescue
      _ -> :ok
    end

    # Unregister from resize callbacks
    try do
      if state.terminal_started do
        Terminal.unregister_resize_callback(self())
      end
    rescue
      _ -> :ok
    end

    # Ensure clean shutdown
    try do
      if not state.shutting_down do
        do_shutdown(state)
      end
    rescue
      _ -> :ok
    end

    # Restore terminal - this is critical for user experience
    try do
      if state.terminal_started do
        Terminal.restore()
      end
    rescue
      _ -> :ok
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
        # Transform event to message, with error handling
        try do
          case module.event_to_msg(event, component_state) do
            {:msg, message} ->
              enqueue_message(component_id, message, state)

            :ignore ->
              state

            :propagate ->
              # Would propagate to parent, for now just ignore
              state
          end
        rescue
          error ->
            require Logger
            Logger.error("Component #{component_id} crashed in event_to_msg: #{inspect(error)}")
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
        # Call update function with error handling
        try do
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
        rescue
          error ->
            require Logger
            Logger.error("Component #{component_id} crashed in update: #{inspect(error)}")
            # Return unchanged state and no commands
            {state, []}
        end
    end
  end

  # --- Command Execution ---

  defp execute_commands([], state), do: state

  defp execute_commands(commands, state) do
    # Check for quit command first
    # Handle both Command struct and legacy atom :quit
    quit_cmd =
      Enum.find(commands, fn {_component_id, cmd} ->
        case cmd do
          %{type: :quit} -> true
          :quit -> true
          _ -> false
        end
      end)

    if quit_cmd do
      # Quit command takes precedence - initiate shutdown
      # Stop the GenServer after cleanup
      GenServer.cast(self(), :shutdown)
      %{state | shutting_down: true}
    else
      # Track pending commands for execution
      pending =
        Enum.reduce(commands, state.pending_commands, fn {component_id, cmd}, acc ->
          command_id = make_ref()
          Map.put(acc, command_id, %{component_id: component_id, command: cmd})
        end)

      %{state | pending_commands: pending}
    end
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
    if state.terminal_started do
      # Call view on root component with error handling
      %{module: module, state: component_state} = Map.get(state.components, :root)

      render_tree =
        try do
          module.view(component_state)
        rescue
          error ->
            require Logger
            Logger.error("Component :root crashed in view: #{inspect(error)}")
            # Return a simple error indicator
            {:text, "[Render Error]"}
        end

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
    else
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

    # Reset style at end of frame to avoid bleeding into next frame
    seq_buffer = SequenceBuffer.append!(seq_buffer, "\e[0m")

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
    buffer = SequenceBuffer.append!(buffer, "\e[0m")
    # Reset style tracking so next style is emitted in full
    SequenceBuffer.reset_style(buffer)
  end

  # --- Resize Handling ---

  defp handle_resize(rows, cols, state) do
    # Skip if terminal not available
    if state.terminal_started do
      # Update dimensions in state
      new_dimensions = {cols, rows}

      # Resize buffer manager
      if state.buffer_manager do
        BufferManager.resize(state.buffer_manager, rows, cols)
      end

      # Clear screen to avoid artifacts
      IO.write("\e[2J")

      # Create resize event and broadcast to all components
      resize_event = Event.Resize.new(cols, rows)
      state = broadcast_event(resize_event, %{state | dimensions: new_dimensions})

      # Mark dirty and force immediate render
      state = %{state | dirty: true}
      do_render(state)
    else
      state
    end
  end

  # --- Shutdown ---

  defp initiate_shutdown(state) do
    state = %{state | shutting_down: true}
    state = do_shutdown(state)

    # Schedule the GenServer to stop after returning from this callback
    # This allows terminate/2 to run and clean up properly
    Process.send_after(self(), :stop_runtime, 0)

    state
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
