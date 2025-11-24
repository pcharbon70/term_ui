defmodule TermUI.Terminal do
  @moduledoc """
  Main terminal management GenServer for TermUI.

  Provides raw mode activation, alternate screen buffer management,
  terminal restoration, and size detection using OTP 28's native
  raw mode support.
  """

  use GenServer
  require Logger

  alias TermUI.Terminal.State

  @ets_table :term_ui_terminal_state

  # Escape sequences
  @enter_alternate_screen "\e[?1049h"
  @leave_alternate_screen "\e[?1049l"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"
  @reset_terminal "\ec"

  # Mouse tracking escape sequences
  @mouse_click_on "\e[?1000h"
  @mouse_click_off "\e[?1000l"
  @mouse_drag_on "\e[?1002h"
  @mouse_drag_off "\e[?1002l"
  @mouse_all_on "\e[?1003h"
  @mouse_all_off "\e[?1003l"
  @mouse_sgr_on "\e[?1006h"
  @mouse_sgr_off "\e[?1006l"

  # Client API

  @doc """
  Starts the Terminal GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enables raw mode on the terminal.

  Calls OTP 28's `shell.start_interactive({:noshell, :raw})` and configures
  the terminal for TUI operation.

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @spec enable_raw_mode() :: {:ok, State.t()} | {:error, term()}
  def enable_raw_mode do
    GenServer.call(__MODULE__, :enable_raw_mode)
  end

  @doc """
  Disables raw mode and restores original terminal settings.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec disable_raw_mode() :: :ok | {:error, term()}
  def disable_raw_mode do
    GenServer.call(__MODULE__, :disable_raw_mode)
  end

  @doc """
  Enters the alternate screen buffer.

  The alternate screen preserves the user's shell history while the TUI runs.
  """
  @spec enter_alternate_screen() :: :ok | {:error, term()}
  def enter_alternate_screen do
    GenServer.call(__MODULE__, :enter_alternate_screen)
  end

  @doc """
  Leaves the alternate screen buffer and restores the original screen.
  """
  @spec leave_alternate_screen() :: :ok | {:error, term()}
  def leave_alternate_screen do
    GenServer.call(__MODULE__, :leave_alternate_screen)
  end

  @doc """
  Hides the cursor.
  """
  @spec hide_cursor() :: :ok
  def hide_cursor do
    GenServer.call(__MODULE__, :hide_cursor)
  end

  @doc """
  Shows the cursor.
  """
  @spec show_cursor() :: :ok
  def show_cursor do
    GenServer.call(__MODULE__, :show_cursor)
  end

  @doc """
  Gets the current terminal size.

  Returns `{:ok, {rows, cols}}` or `{:error, reason}`.
  """
  @spec get_terminal_size() :: {:ok, {pos_integer(), pos_integer()}} | {:error, term()}
  def get_terminal_size do
    GenServer.call(__MODULE__, :get_terminal_size)
  end

  @doc """
  Registers a process to receive terminal resize notifications.

  The registered process will receive `{:terminal_resize, {rows, cols}}` messages.
  """
  @spec register_resize_callback(pid()) :: :ok
  def register_resize_callback(pid \\ self()) do
    GenServer.call(__MODULE__, {:register_resize_callback, pid})
  end

  @doc """
  Unregisters a process from resize notifications.
  """
  @spec unregister_resize_callback(pid()) :: :ok
  def unregister_resize_callback(pid \\ self()) do
    GenServer.call(__MODULE__, {:unregister_resize_callback, pid})
  end

  @doc """
  Performs complete terminal restoration.

  This restores all terminal modifications in the correct sequence:
  1. Show cursor
  2. Leave alternate screen
  3. Disable raw mode
  4. Restore original settings
  """
  @spec restore() :: :ok | {:error, term()}
  def restore do
    GenServer.call(__MODULE__, :restore)
  end

  @doc """
  Checks if the terminal is currently in raw mode.
  """
  @spec raw_mode?() :: boolean()
  def raw_mode? do
    GenServer.call(__MODULE__, :raw_mode?)
  end

  @doc """
  Gets the current terminal state.
  """
  @spec get_state() :: State.t()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Enables mouse tracking with the specified mode.

  ## Modes

  - `:click` - Report button press and release only
  - `:drag` - Also report mouse motion while button is pressed
  - `:all` - Report all mouse motion (generates many events)

  Also enables SGR extended mode for accurate coordinates.
  """
  @spec enable_mouse_tracking(:click | :drag | :all) :: :ok
  def enable_mouse_tracking(mode \\ :click) when mode in [:click, :drag, :all] do
    GenServer.call(__MODULE__, {:enable_mouse_tracking, mode})
  end

  @doc """
  Disables mouse tracking.
  """
  @spec disable_mouse_tracking() :: :ok
  def disable_mouse_tracking do
    GenServer.call(__MODULE__, :disable_mouse_tracking)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    check_previous_crash()
    create_ets_table()

    state = State.new()
    {:ok, state}
  end

  @impl true
  def handle_call(:enable_raw_mode, _from, state) do
    if state.raw_mode_active do
      {:reply, {:ok, state}, state}
    else
      case do_enable_raw_mode() do
        {:ok, original_settings} ->
          :ets.insert(@ets_table, {:raw_mode_active, true})

          new_state = %{state | raw_mode_active: true, original_settings: original_settings}
          {:reply, {:ok, new_state}, new_state}

        {:error, _reason} = error ->
          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_call(:disable_raw_mode, _from, state) do
    if state.raw_mode_active do
      do_disable_raw_mode(state.original_settings)
      :ets.insert(@ets_table, {:raw_mode_active, false})
      new_state = %{state | raw_mode_active: false, original_settings: nil}
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:enter_alternate_screen, _from, state) do
    if state.alternate_screen_active do
      {:reply, :ok, state}
    else
      write_to_terminal(@enter_alternate_screen)
      new_state = %{state | alternate_screen_active: true}
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:leave_alternate_screen, _from, state) do
    if state.alternate_screen_active do
      write_to_terminal(@leave_alternate_screen)
      new_state = %{state | alternate_screen_active: false}
      {:reply, :ok, new_state}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:hide_cursor, _from, state) do
    write_to_terminal(@hide_cursor)
    new_state = %{state | cursor_visible: false}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:show_cursor, _from, state) do
    write_to_terminal(@show_cursor)
    new_state = %{state | cursor_visible: true}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_terminal_size, _from, state) do
    case do_get_terminal_size() do
      {:ok, {rows, cols}} = result ->
        new_state = %{state | size: {rows, cols}}
        {:reply, result, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:register_resize_callback, pid}, _from, state) do
    callbacks = [pid | state.resize_callbacks] |> Enum.uniq()
    new_state = %{state | resize_callbacks: callbacks}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_resize_callback, pid}, _from, state) do
    callbacks = Enum.reject(state.resize_callbacks, &(&1 == pid))
    new_state = %{state | resize_callbacks: callbacks}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:restore, _from, state) do
    new_state = do_restore(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:raw_mode?, _from, state) do
    {:reply, state.raw_mode_active, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:enable_mouse_tracking, mode}, _from, state) do
    # First disable any existing tracking
    if state.mouse_tracking != :off do
      disable_current_mouse_mode(state.mouse_tracking)
    end

    # Enable new tracking mode with SGR
    case mode do
      :click ->
        write_to_terminal(@mouse_click_on)
        write_to_terminal(@mouse_sgr_on)

      :drag ->
        write_to_terminal(@mouse_drag_on)
        write_to_terminal(@mouse_sgr_on)

      :all ->
        write_to_terminal(@mouse_all_on)
        write_to_terminal(@mouse_sgr_on)
    end

    new_state = %{state | mouse_tracking: mode}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:disable_mouse_tracking, _from, state) do
    if state.mouse_tracking != :off do
      disable_current_mouse_mode(state.mouse_tracking)
      write_to_terminal(@mouse_sgr_off)
    end

    new_state = %{state | mouse_tracking: :off}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:EXIT, _pid, :normal}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, :shutdown}, state) do
    Logger.debug("Terminal GenServer received shutdown, performing cleanup")
    do_restore(state)
    {:stop, :shutdown, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.warning("Terminal GenServer received EXIT: #{inspect(reason)}, performing cleanup")
    do_restore(state)
    {:stop, reason, state}
  end

  @impl true
  def handle_info(:sigwinch, state) do
    case do_get_terminal_size() do
      {:ok, {rows, cols}} ->
        new_state = %{state | size: {rows, cols}}

        for pid <- new_state.resize_callbacks do
          send(pid, {:terminal_resize, {rows, cols}})
        end

        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug("Terminal GenServer terminating: #{inspect(reason)}")
    do_restore(state)
    :ok
  end

  # Private functions

  defp do_enable_raw_mode do
    if terminal?() do
      try do
        # OTP 28 raw mode activation
        # This sets character-at-a-time mode with no echo
        case :shell.start_interactive({:noshell, :raw}) do
          :ok ->
            {:ok, :raw_mode}

          {:error, reason} ->
            {:error, reason}
        end
      rescue
        _e in UndefinedFunctionError ->
          # Not OTP 28+
          {:error, {:otp_version, "OTP 28+ required for raw mode support"}}

        e ->
          {:error, {:raw_mode_failed, Exception.message(e)}}
      catch
        kind, reason ->
          {:error, {kind, reason}}
      end
    else
      {:error, :not_a_terminal}
    end
  end

  defp do_disable_raw_mode(_original_settings) do
    write_to_terminal(@reset_terminal)
    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp do_get_terminal_size do
    if function_exported?(:io, :columns, 0) and function_exported?(:io, :rows, 0) do
      case {:io.columns(), :io.rows()} do
        {{:ok, cols}, {:ok, rows}} ->
          {:ok, {rows, cols}}

        _ ->
          get_size_from_env()
      end
    else
      get_size_from_env()
    end
  end

  defp get_size_from_env do
    # Try LINES and COLUMNS environment variables
    with {:ok, lines} <- get_env_int("LINES"),
         {:ok, columns} <- get_env_int("COLUMNS") do
      {:ok, {lines, columns}}
    else
      _ ->
        # Try stty as last resort
        get_size_from_stty()
    end
  end

  defp get_env_int(var) do
    case System.get_env(var) do
      nil ->
        {:error, :not_set}

      value ->
        case Integer.parse(value) do
          {int, ""} when int > 0 -> {:ok, int}
          _ -> {:error, :invalid}
        end
    end
  end

  defp get_size_from_stty do
    case System.cmd("stty", ["size"], stderr_to_stdout: true) do
      {output, 0} ->
        case String.split(String.trim(output)) do
          [rows_str, cols_str] ->
            with {rows, ""} <- Integer.parse(rows_str),
                 {cols, ""} <- Integer.parse(cols_str) do
              {:ok, {rows, cols}}
            else
              _ -> {:error, :parse_failed}
            end

          _ ->
            {:error, :invalid_output}
        end

      {_, _} ->
        {:error, :stty_failed}
    end
  rescue
    _ -> {:error, :stty_failed}
  end

  defp do_restore(state) do
    if not state.cursor_visible do
      write_to_terminal(@show_cursor)
    end

    if state.mouse_tracking != :off do
      disable_current_mouse_mode(state.mouse_tracking)
      write_to_terminal(@mouse_sgr_off)
    end

    if state.alternate_screen_active do
      write_to_terminal(@leave_alternate_screen)
    end

    if state.raw_mode_active do
      do_disable_raw_mode(state.original_settings)
    end

    if :ets.whereis(@ets_table) != :undefined do
      :ets.insert(@ets_table, {:raw_mode_active, false})
    end

    State.new()
  end

  defp disable_current_mouse_mode(mode) do
    case mode do
      :click -> write_to_terminal(@mouse_click_off)
      :drag -> write_to_terminal(@mouse_drag_off)
      :all -> write_to_terminal(@mouse_all_off)
      _ -> :ok
    end
  end

  defp write_to_terminal(data) do
    IO.write(data)
  rescue
    _ -> :ok
  end

  defp terminal? do
    case :io.getopts(:standard_io) do
      {:ok, opts} ->
        Keyword.has_key?(opts, :terminal)

      _ ->
        check_tty()
    end
  end

  defp check_tty do
    case System.cmd("test", ["-t", "1"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp create_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set])
    end
  end

  defp check_previous_crash do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, :raw_mode_active) do
        [{:raw_mode_active, true}] ->
          Logger.warning("Detected unclean termination from previous run, resetting terminal")
          write_to_terminal(@show_cursor)
          write_to_terminal(@leave_alternate_screen)
          write_to_terminal(@reset_terminal)

        _ ->
          :ok
      end
    end
  end
end
