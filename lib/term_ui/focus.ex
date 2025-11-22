defmodule TermUI.Focus do
  @moduledoc """
  Focus event utilities for terminal window focus tracking.

  Provides escape sequences and utilities for detecting when the
  terminal window gains or loses system focus. This enables optimization
  opportunities like pausing animations when backgrounded.

  ## Usage

      # Enable focus reporting
      IO.write(Focus.enable())

      # Check if focus reporting is supported
      if Focus.supported?() do
        IO.write(Focus.enable())
      end

      # Disable focus reporting
      IO.write(Focus.disable())
  """

  # Focus reporting mode
  # ESC [ ? 1004 h - Enable focus reporting
  # ESC [ ? 1004 l - Disable focus reporting
  @focus_enable "\e[?1004h"
  @focus_disable "\e[?1004l"

  # Focus event sequences
  # ESC [ I - Focus gained
  # ESC [ O - Focus lost
  @focus_gained "\e[I"
  @focus_lost "\e[O"

  @doc """
  Returns escape sequence to enable focus reporting.
  """
  @spec enable() :: String.t()
  def enable, do: @focus_enable

  @doc """
  Returns escape sequence to disable focus reporting.
  """
  @spec disable() :: String.t()
  def disable, do: @focus_disable

  @doc """
  Returns the focus gained sequence.
  """
  @spec gained_sequence() :: String.t()
  def gained_sequence, do: @focus_gained

  @doc """
  Returns the focus lost sequence.
  """
  @spec lost_sequence() :: String.t()
  def lost_sequence, do: @focus_lost

  @doc """
  Checks if focus reporting is likely supported.

  This is a heuristic check based on terminal type. Many modern
  terminals support focus reporting but don't advertise it.

  Known supporting terminals:
  - xterm (with allowWindowOps)
  - iTerm2
  - Alacritty
  - Kitty
  - WezTerm
  - foot
  - GNOME Terminal
  - Windows Terminal
  """
  @spec supported?() :: boolean()
  def supported? do
    term = System.get_env("TERM", "")
    term_program = System.get_env("TERM_PROGRAM", "")

    cond do
      # Known good terminals
      String.contains?(term_program, "iTerm") -> true
      String.contains?(term_program, "Alacritty") -> true
      String.contains?(term_program, "WezTerm") -> true
      System.get_env("KITTY_WINDOW_ID") != nil -> true
      System.get_env("WT_SESSION") != nil -> true
      # xterm and derivatives
      String.starts_with?(term, "xterm") -> true
      # foot terminal
      term == "foot" or term == "foot-extra" -> true
      # VTE-based terminals (GNOME Terminal, etc.)
      System.get_env("VTE_VERSION") != nil -> true
      # Conservative default
      true -> false
    end
  end

  @doc """
  Parses input to detect focus events.

  Returns `{:focus, :gained}`, `{:focus, :lost}`, or `nil` if not a focus event.
  """
  @spec parse(String.t()) :: {:focus, :gained | :lost} | nil
  def parse(@focus_gained), do: {:focus, :gained}
  def parse(@focus_lost), do: {:focus, :lost}
  def parse(_), do: nil
end

defmodule TermUI.Focus.Tracker do
  @moduledoc """
  Focus state tracker with action registration.

  Maintains focus state and executes registered actions when
  focus changes. Supports optimization hooks for reducing work
  when the application is backgrounded.

  ## Usage

      {:ok, tracker} = Focus.Tracker.start_link()

      # Register focus actions
      Focus.Tracker.on_focus_lost(tracker, fn ->
        save_state()
      end)

      Focus.Tracker.on_focus_gained(tracker, fn ->
        refresh_content()
      end)

      # Update focus state
      Focus.Tracker.set_focus(tracker, true)

      # Query focus state
      Focus.Tracker.has_focus?(tracker)
  """

  use GenServer

  @type t :: %__MODULE__{
          has_focus: boolean(),
          on_gained: [(() -> any())],
          on_lost: [(() -> any())],
          paused: boolean(),
          reduced_framerate: boolean(),
          auto_pause: boolean(),
          auto_reduce_framerate: boolean()
        }

  defstruct has_focus: true,
            on_gained: [],
            on_lost: [],
            paused: false,
            reduced_framerate: false,
            auto_pause: false,
            auto_reduce_framerate: false

  # --- Public API ---

  @doc """
  Starts the focus tracker.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Sets the focus state.
  """
  @spec set_focus(GenServer.server(), boolean()) :: :ok
  def set_focus(tracker, focused) when is_boolean(focused) do
    GenServer.call(tracker, {:set_focus, focused})
  end

  @doc """
  Returns true if the application has focus.
  """
  @spec has_focus?(GenServer.server()) :: boolean()
  def has_focus?(tracker) do
    GenServer.call(tracker, :has_focus?)
  end

  @doc """
  Registers an action to execute when focus is gained.
  """
  @spec on_focus_gained(GenServer.server(), (() -> any())) :: :ok
  def on_focus_gained(tracker, action) when is_function(action, 0) do
    GenServer.call(tracker, {:on_focus_gained, action})
  end

  @doc """
  Registers an action to execute when focus is lost.
  """
  @spec on_focus_lost(GenServer.server(), (() -> any())) :: :ok
  def on_focus_lost(tracker, action) when is_function(action, 0) do
    GenServer.call(tracker, {:on_focus_lost, action})
  end

  @doc """
  Clears all registered actions.
  """
  @spec clear_actions(GenServer.server()) :: :ok
  def clear_actions(tracker) do
    GenServer.call(tracker, :clear_actions)
  end

  @doc """
  Returns true if animations should be paused.

  This is set when focus is lost and auto_pause is enabled.
  """
  @spec paused?(GenServer.server()) :: boolean()
  def paused?(tracker) do
    GenServer.call(tracker, :paused?)
  end

  @doc """
  Sets the paused state manually.
  """
  @spec set_paused(GenServer.server(), boolean()) :: :ok
  def set_paused(tracker, paused) when is_boolean(paused) do
    GenServer.call(tracker, {:set_paused, paused})
  end

  @doc """
  Returns true if framerate should be reduced.

  This is set when focus is lost and auto_reduce_framerate is enabled.
  """
  @spec reduced_framerate?(GenServer.server()) :: boolean()
  def reduced_framerate?(tracker) do
    GenServer.call(tracker, :reduced_framerate?)
  end

  @doc """
  Sets the reduced framerate state manually.
  """
  @spec set_reduced_framerate(GenServer.server(), boolean()) :: :ok
  def set_reduced_framerate(tracker, reduced) when is_boolean(reduced) do
    GenServer.call(tracker, {:set_reduced_framerate, reduced})
  end

  @doc """
  Enables automatic pause when focus is lost.
  """
  @spec enable_auto_pause(GenServer.server()) :: :ok
  def enable_auto_pause(tracker) do
    GenServer.call(tracker, :enable_auto_pause)
  end

  @doc """
  Enables automatic framerate reduction when focus is lost.
  """
  @spec enable_auto_reduce_framerate(GenServer.server()) :: :ok
  def enable_auto_reduce_framerate(tracker) do
    GenServer.call(tracker, :enable_auto_reduce_framerate)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    state = %__MODULE__{
      has_focus: Keyword.get(opts, :initial_focus, true)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:set_focus, focused}, _from, state) do
    if focused == state.has_focus do
      {:reply, :ok, state}
    else
      # Update focus state
      state = %{state | has_focus: focused}

      # Update auto-pause and auto-reduce states
      state =
        if state.auto_pause do
          %{state | paused: not focused}
        else
          state
        end

      state =
        if state.auto_reduce_framerate do
          %{state | reduced_framerate: not focused}
        else
          state
        end

      # Execute actions
      actions = if focused, do: state.on_gained, else: state.on_lost

      Enum.each(actions, fn action ->
        try do
          action.()
        rescue
          _ -> :ok
        end
      end)

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:has_focus?, _from, state) do
    {:reply, state.has_focus, state}
  end

  @impl true
  def handle_call({:on_focus_gained, action}, _from, state) do
    state = %{state | on_gained: state.on_gained ++ [action]}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:on_focus_lost, action}, _from, state) do
    state = %{state | on_lost: state.on_lost ++ [action]}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_actions, _from, state) do
    state = %{state | on_gained: [], on_lost: []}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:paused?, _from, state) do
    {:reply, state.paused, state}
  end

  @impl true
  def handle_call({:set_paused, paused}, _from, state) do
    {:reply, :ok, %{state | paused: paused}}
  end

  @impl true
  def handle_call(:reduced_framerate?, _from, state) do
    {:reply, state.reduced_framerate, state}
  end

  @impl true
  def handle_call({:set_reduced_framerate, reduced}, _from, state) do
    {:reply, :ok, %{state | reduced_framerate: reduced}}
  end

  @impl true
  def handle_call(:enable_auto_pause, _from, state) do
    {:reply, :ok, %{state | auto_pause: true}}
  end

  @impl true
  def handle_call(:enable_auto_reduce_framerate, _from, state) do
    {:reply, :ok, %{state | auto_reduce_framerate: true}}
  end
end
