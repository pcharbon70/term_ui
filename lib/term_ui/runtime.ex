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
  require Logger

  alias TermUI.Backend.Selector
  alias TermUI.Config
  alias TermUI.Elm
  alias TermUI.EventQueue
  alias TermUI.Event
  alias TermUI.Input.Selector, as: InputSelector
  alias TermUI.MessageQueue
  alias TermUI.PersistentTerms
  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.BufferManager
  alias TermUI.Renderer.Cell
  alias TermUI.Runtime.NodeRenderer
  alias TermUI.Runtime.State
  alias TermUI.Terminal
  alias TermUI.Terminal.InputReader

  @type option ::
          {:root, module()}
          | {:name, GenServer.name()}
          | {:render_interval, pos_integer()}
          | {:backend, :auto | :raw | :tty}
          | {:skip_terminal, boolean()}
          | {:use_input_handler, boolean()}

  # Default render interval in milliseconds (~60 FPS)
  @default_render_interval 16

  # Input polling interval (same as render interval)
  @input_poll_interval 16

  # --- Public API ---

  @doc """
  Starts the runtime with the given options.

  ## Options

  - `:root` - The root component module (required)
  - `:name` - GenServer name (optional)
  - `:render_interval` - Milliseconds between renders (default: 16)
  - `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
  - `:skip_terminal` - Skip terminal initialization (default: false, for testing)

  ## Backend Selection

  The `:backend` option controls which terminal backend is used:

  - `:auto` (default) - Attempts raw mode first, falls back to TTY if unavailable
  - `:raw` - Forces raw mode (requires OTP 28+, errors if unavailable)
  - `:tty` - Forces TTY mode (line-based input, no raw mode attempt)

  ## Examples

      # Auto-detect backend (default behavior)
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root)

      # Force TTY mode
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root, backend: :tty)

      # Query backend mode at runtime
      :raw = Runtime.backend_mode()

      # Query capabilities (useful for TTY mode)
      %{colors: :true_color, unicode: true} = Runtime.capabilities()
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
  Returns a child specification for starting the runtime in a supervisor.

  ## Options

  Same as `start_link/1`:
  - `:root` - The root component module (required)
  - `:name` - GenServer name (optional)
  - `:render_interval` - Milliseconds between renders (default: 16)
  - `:backend` - Backend selection: `:auto`, `:raw`, `:tty`
  - `:skip_terminal` - Skip terminal initialization (default: false)

  ## Examples

      children = [
        {TermUI.Runtime, root: MyApp.Root, name: :my_runtime}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
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
  Gets the current backend mode.

  Returns `:raw` if raw mode is active, `:tty` if TTY mode is active,
  or `nil` if no runtime has been started.

  ## Examples

      :raw = Runtime.backend_mode()
      :tty = Runtime.backend_mode()
  """
  @spec backend_mode() :: State.backend_mode()
  def backend_mode, do: PersistentTerms.backend_mode()

  @doc """
  Gets the detected terminal capabilities.

  Returns a map with keys:
  - `:colors` - Color depth (`:true_color`, `:color_256`, `:color_16`, `:monochrome`)
  - `:unicode` - Boolean indicating Unicode support
  - `:dimensions` - `{rows, cols}` tuple or `nil`
  - `:terminal` - Boolean indicating terminal presence

  Returns `nil` if no runtime has been started.

  ## Examples

      %{colors: :true_color, unicode: true} = Runtime.capabilities()
  """
  @spec capabilities() :: State.capabilities() | nil
  def capabilities, do: PersistentTerms.capabilities()

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

    # Merge runtime options with application configuration
    # Runtime options take precedence over config
    opts = Config.merge_options(opts)

    root_module = Keyword.fetch!(opts, :root)
    render_interval = Keyword.get(opts, :render_interval, @default_render_interval)
    skip_terminal = Keyword.get(opts, :skip_terminal, false)
    backend_opt = Keyword.get(opts, :backend, :auto)
    use_input_handler = Keyword.get(opts, :use_input_handler, false)

    # Select backend using Backend.Selector
    {backend_mode, backend, backend_state, capabilities, terminal_started, buffer_manager, dimensions} =
      if skip_terminal do
        {:skip, nil, nil, nil, false, nil, nil}
      else
        select_backend(backend_opt)
      end

    # Store backend info in persistent_term for global access
    PersistentTerms.store_backend_context(backend_mode, capabilities)

    # Initialize root component state
    root_state = root_module.init(opts)

    # TTY mode requires the new input handler (IEx compatible)
    # Raw mode can use either InputReader (legacy) or Input.Raw (new)
    use_input_handler = use_input_handler or backend_mode == :tty

    # Select and initialize input handler (if enabled)
    {input_handler, input_state} =
      if use_input_handler and backend_mode in [:raw, :tty] do
        handler = InputSelector.select(backend_mode)
        {handler, handler.new()}
      else
        {nil, nil}
      end

    # Start input reader and register for resize callbacks if using legacy InputReader
    input_reader =
      if not use_input_handler and terminal_started do
        {:ok, reader_pid} = InputReader.start_link(target: self())
        Terminal.register_resize_callback(self())
        reader_pid
      else
        nil
      end

    # Register for resize callbacks if using new input handler
    # TTY backend also needs resize events even though terminal_started=false
    if use_input_handler and backend_mode in [:raw, :tty] do
      # Only register if Terminal GenServer is running
      if Process.whereis(Terminal) do
        Terminal.register_resize_callback(self())
      end
    end

    state = %State{
      root_module: root_module,
      root_state: root_state,
      message_queue: MessageQueue.new(),
      event_queue: EventQueue.new(),
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
      input_reader: input_reader,
      backend_mode: backend_mode,
      backend: backend,
      backend_state: backend_state,
      capabilities: capabilities,
      input_handler: input_handler,
      input_state: input_state
    }

    # Schedule first render
    schedule_render(render_interval)

    # Schedule first input poll (if using new input handler)
    if input_handler do
      schedule_input_poll()
    end

    {:ok, state}
  end

  defp select_backend(backend_opt) do
    case Selector.select(backend_opt) do
      {:raw, _raw_state} ->
        # Raw mode succeeded - set up terminal and buffers
        case setup_terminal_and_buffers() do
          {true, buffer_manager, dimensions} ->
            backend = TermUI.Backend.Raw
            # Initialize Raw backend with terminal setup
            {:ok, backend_state} = backend.init(
              alternate_screen: true,
              hide_cursor: true,
              mouse_tracking: :all,
              size: dimensions
            )
            {:raw, backend, backend_state, nil, true, buffer_manager, dimensions}

          {false, nil, nil} ->
            # Terminal setup failed, fall back to TTY
            capabilities = Selector.detect_capabilities()
            backend = TermUI.Backend.TTY
            {:ok, backend_state} = backend.init(capabilities: capabilities)
            {:tty, backend, backend_state, capabilities, false, nil, nil}
        end

      {:tty, capabilities} ->
        # TTY mode - no terminal setup, no buffer manager
        backend = TermUI.Backend.TTY
        {:ok, backend_state} = backend.init(capabilities: capabilities)
        {:tty, backend, backend_state, capabilities, false, nil, nil}

      {:explicit, :raw, _opts} ->
        # Explicit raw backend selection - atom form
        case setup_terminal_and_buffers() do
          {true, buffer_manager, dimensions} ->
            backend = TermUI.Backend.Raw
            {:ok, backend_state} = backend.init(
              alternate_screen: true,
              hide_cursor: true,
              mouse_tracking: :all,
              size: dimensions
            )
            {:raw, backend, backend_state, nil, true, buffer_manager, dimensions}

          {false, nil, nil} ->
            raise "Raw backend requested but unavailable"
        end

      {:explicit, :tty, _opts} ->
        # Explicit TTY backend selection - atom form
        capabilities = Selector.detect_capabilities()
        backend = TermUI.Backend.TTY
        {:ok, backend_state} = backend.init(capabilities: capabilities)
        {:tty, backend, backend_state, capabilities, false, nil, nil}

      {:explicit, module, _opts} ->
        # Explicit backend selection - module form (TermUI.Backend.Raw or TermUI.Backend.TTY)
        case module do
          TermUI.Backend.Raw ->
            case setup_terminal_and_buffers() do
              {true, buffer_manager, dimensions} ->
                {:ok, backend_state} = module.init(
                  alternate_screen: true,
                  hide_cursor: true,
                  mouse_tracking: :all,
                  size: dimensions
                )
                {:raw, module, backend_state, nil, true, buffer_manager, dimensions}

              {false, nil, nil} ->
                raise "Raw backend requested but unavailable"
            end

          TermUI.Backend.TTY ->
            capabilities = Selector.detect_capabilities()
            {:ok, backend_state} = module.init(capabilities: capabilities)
            {:tty, module, backend_state, capabilities, false, nil, nil}
        end
    end
  end

  defp setup_terminal_and_buffers do
    # Start Terminal GenServer first, before calling any Terminal API functions
    # The Terminal GenServer will detect if raw mode is already active (e.g., from Selector)
    with {:ok, _pid} <- Terminal.start_link(),
         :ok <- Terminal.enter_alternate_screen(),
         :ok <- Terminal.hide_cursor(),
         :ok <- Terminal.enable_mouse_tracking(:all),
         {rows, cols} <- get_terminal_dimensions_safe(),
         {:ok, buffer_pid} <- BufferManager.start_link(rows: rows, cols: cols) do
      {true, buffer_pid, {cols, rows}}
    else
      {:error, {:already_started, buffer_pid}} ->
        # BufferManager already started, use it
        {rows, cols} = get_terminal_dimensions_safe()
        {true, buffer_pid, {cols, rows}}

      {:error, _reason} ->
        {false, nil, nil}

      _ ->
        {false, nil, nil}
    end
  rescue
    _ -> {false, nil, nil}
  end

  defp get_terminal_dimensions_safe do
    case Terminal.get_terminal_size() do
      {:ok, {rows, cols}} -> {rows, cols}
      {:error, _reason} -> {24, 80}
    end
  end

  @impl true
  def handle_cast({:event, event}, state) do
    if state.shutting_down do
      {:noreply, state}
    else
      # Add to bounded event queue (may drop oldest if full)
      {result, new_queue} = EventQueue.push(state.event_queue, event)
      state = %{state | event_queue: new_queue}
      # Log if event was dropped
      case result do
        {:dropped, _} -> :ok  # EventQueue already logged
        :ok -> :ok
      end
      # Process queued events
      state = process_event_queue(state)
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
  def handle_info(:input_poll, state) do
    # Poll input handler for new events
    if state.shutting_down or state.input_handler == nil do
      {:noreply, state}
    else
      case state.input_handler.poll(state.input_state, @input_poll_interval) do
        {{:ok, event}, new_input_state} ->
          # Dispatch the event and continue polling
          state = %{state | input_state: new_input_state}
          state = dispatch_event(event, state)
          schedule_input_poll()
          {:noreply, state}

        {:timeout, new_input_state} ->
          # No input, but continue polling
          schedule_input_poll()
          {:noreply, %{state | input_state: new_input_state}}

        {:eof, _new_input_state} ->
          # EOF - initiate shutdown
          state = initiate_shutdown(%{state | input_state: nil})
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:input, event}, state) do
    # Keyboard/mouse input from InputReader
    if state.shutting_down do
      {:noreply, state}
    else
      # Add to bounded event queue (may drop oldest if full)
      {result, new_queue} = EventQueue.push(state.event_queue, event)
      state = %{state | event_queue: new_queue}
      # Process queued events
      state = process_event_queue(state)
      # Log if event was dropped (EventQueue handles rate limiting)
      case result do
        {:dropped, _} -> :ok
        :ok -> :ok
      end
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
          # Tag commands with root component_id
          tagged_commands = Enum.map(commands, fn cmd -> {:root, cmd} end)
          state = execute_commands(tagged_commands, state)
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

    # Stop input handler to restore IO options (TTY mode)
    try do
      if state.input_handler and state.input_state do
        state.input_handler.stop(state.input_state)
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

    # Shutdown backend - this handles terminal restoration
    try do
      if state.backend and state.backend_state do
        state.backend.shutdown(state.backend_state)
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

    # Restore terminal via Terminal module - this is the legacy path
    # and provides defense-in-depth if backend shutdown didn't fully restore
    try do
      if state.terminal_started and state.backend == nil do
        # Only do this if backend.shutdown wasn't called (defense in depth)
        Terminal.restore()
      end
    rescue
      _ -> :ok
    end

    # Defensive cleanup: directly write mouse disable sequences to terminal
    # This ensures cleanup even if backend shutdown is unavailable or crashed
    try do
      # Disable all mouse tracking modes
      IO.write("\e[?1006l\e[?1003l\e[?1002l\e[?1000l")
      # Show cursor
      IO.write("\e[?25h")
    rescue
      _ -> :ok
    end

    # Clean up persistent_term storage to prevent memory leaks
    try do
      PersistentTerms.cleanup()
    rescue
      _ -> :ok
    end

    :ok
  end

  # --- Event Dispatch ---

  # Processes events from the bounded event queue.
  #
  # Processes one event per call to prevent event loop starvation.
  # Multiple events will be processed across multiple GenServer handle_info/call cycles.
  defp process_event_queue(state) do
    case EventQueue.pop(state.event_queue) do
      {{:value, event}, new_queue} ->
        state = %{state | event_queue: new_queue}
        dispatch_event(event, state)

      {:empty, _} ->
        state
    end
  end

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

  defp schedule_input_poll do
    Process.send_after(self(), :input_poll, @input_poll_interval)
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
    # Render if backend is available (TTY backend works even without terminal_started)
    if state.backend do
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

      # Different rendering paths for Raw vs TTY backends
      {cells, new_backend_state} =
        if state.buffer_manager do
          # Raw backend: use double buffering with diffing
          render_with_buffer_manager(render_tree, state)
        else
          # TTY backend: create temporary buffer, render all cells
          render_to_tty_backend(render_tree, state)
        end

      # Delegate rendering to backend
      {:ok, new_backend_state} = state.backend.draw_cells(new_backend_state, cells)

      # Flush any pending output
      {:ok, ^new_backend_state} = state.backend.flush(new_backend_state)

      %{state | dirty: false, backend_state: new_backend_state}
    else
      %{state | dirty: false}
    end
  end

  # Renders using BufferManager with double buffering and diffing (Raw backend)
  defp render_with_buffer_manager(render_tree, state) do
    # Clear current buffer
    BufferManager.clear_current(state.buffer_manager)

    # Render tree to buffer
    NodeRenderer.render_to_buffer(render_tree, state.buffer_manager)

    # Get buffers for diffing
    current = BufferManager.get_current_buffer(state.buffer_manager)
    previous = BufferManager.get_previous_buffer(state.buffer_manager)

    # Get changed cells and convert to backend format
    cells = get_changed_cells(current, previous)

    # Swap buffers
    BufferManager.swap_buffers(state.buffer_manager)

    {cells, state.backend_state}
  end

  # Renders to TTY backend without double buffering
  defp render_to_tty_backend(render_tree, state) do
    # Get terminal size from backend state or capabilities
    {rows, cols} =
      case state.backend_state do
        %{size: {r, c}} -> {r, c}
        _ -> {24, 80}
      end

    # Create temporary buffer for this frame
    case TermUI.Renderer.Buffer.new(rows, cols) do
      {:ok, temp_buffer} ->
        # Render tree directly to temporary buffer (bypassing BufferManager)
        NodeRenderer.render_to_buffer_direct(render_tree, temp_buffer)

        # Extract all non-empty cells for TTY backend
        cells = extract_all_cells(temp_buffer)

        # Clean up temporary buffer
        TermUI.Renderer.Buffer.destroy(temp_buffer)

        {cells, state.backend_state}

      {:error, _reason} ->
        # If buffer creation fails, render nothing
        {[], state.backend_state}
    end
  end

  # Extracts all non-empty cells from buffer for TTY backend
  defp extract_all_cells(buffer) do
    {rows, _cols} = TermUI.Renderer.Buffer.dimensions(buffer)

    for row <- 1..rows, reduce: [] do
      acc ->
        buffer_row = TermUI.Renderer.Buffer.get_row(buffer, row)

        cells_in_row =
          buffer_row
          |> Enum.with_index(1)
          |> Enum.filter(fn {%TermUI.Renderer.Cell{char: char}, _col} -> char != " " end)
          |> Enum.flat_map(fn {cell, col} -> cell_to_backend_tuple(cell, row, col) end)

        cells_in_row ++ acc
    end
  end

  # Gets changed cells by comparing current and previous buffers.
  # Returns cells in the format expected by Backend.draw_cells/2: [{position, cell_data}]
  # where position is {row, col} and cell_data is {char, fg, bg, attrs}
  defp get_changed_cells(current, previous) do
    {rows, _cols} = Buffer.dimensions(current)

    # Iterate through all cells and collect changed ones
    # For efficiency, we use the Diff module's row comparison
    for row <- 1..rows, reduce: [] do
      acc ->
        current_row = Buffer.get_row(current, row)
        previous_row = Buffer.get_row(previous, row)

        # Find changed cells in this row (non-empty cells only for efficiency)
        changed_in_row =
          current_row
          |> Enum.with_index(1)
          |> Enum.filter(fn {%Cell{char: char}, _col} -> char != " " end)
          |> Enum.filter(fn {cell, col} ->
            prev_cell = Enum.at(previous_row, col - 1, Cell.empty())
            not Cell.equal?(cell, prev_cell)
          end)
          |> Enum.flat_map(fn {cell, col} ->
            cell_to_backend_tuple(cell, row, col)
          end)

        changed_in_row ++ acc
    end
  end

  # Converts a Cell struct to the backend format: {{row, col}, {char, fg, bg, attrs}}
  # Skips wide placeholder cells (they're part of wide characters)
  # Returns [] for skipped cells to filter them out
  defp cell_to_backend_tuple(%Cell{wide_placeholder: true}, _row, _col), do: []

  defp cell_to_backend_tuple(%Cell{char: char, fg: fg, bg: bg, attrs: attrs}, row, col) do
    # Convert MapSet attrs to list for backend format
    attrs_list = MapSet.to_list(attrs)
    [{{row, col}, {char, normalize_color(fg), normalize_color(bg), attrs_list}}]
  end

  # Normalizes colors to ensure :default instead of nil
  defp normalize_color(nil), do: :default
  defp normalize_color(color), do: color

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
