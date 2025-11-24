defmodule TermUI.Command do
  @moduledoc """
  Commands represent side effects to be performed by the runtime.

  Commands are data describing effects - they don't execute immediately.
  The runtime interprets commands and performs the actual effects,
  sending result messages back to components.

  ## Command Types

  - `:timer` - Deliver message after delay
  - `:interval` - Deliver repeated messages at interval
  - `:file_read` - Read file contents
  - `:send_after` - Send message to component after delay
  - `:quit` - Request application shutdown
  - `:none` - No-op command (useful for conditional commands)

  ## Usage

      # In component update function
      def update(:start_timer, state) do
        cmd = Command.timer(1000, :timer_fired)
        {%{state | timer_active: true}, [cmd]}
      end

      def update(:timer_fired, state) do
        {%{state | timer_active: false, count: state.count + 1}, []}
      end
  """

  @type t :: %__MODULE__{
          id: reference() | nil,
          type: atom(),
          payload: term(),
          on_result: term(),
          timeout: pos_integer() | :infinity
        }

  @type command_type :: :timer | :interval | :file_read | :send_after | :quit | :none

  defstruct [
    :id,
    :type,
    :payload,
    :on_result,
    timeout: :infinity
  ]

  @doc """
  Creates a timer command that delivers a message after delay.

  ## Examples

      Command.timer(1000, :timer_done)
      Command.timer(500, {:tick, 1})
  """
  @spec timer(pos_integer(), term()) :: t()
  def timer(delay_ms, on_result) when is_integer(delay_ms) and delay_ms > 0 do
    %__MODULE__{
      type: :timer,
      payload: delay_ms,
      on_result: on_result
    }
  end

  @doc """
  Creates an interval command that delivers repeated messages.

  The interval continues until cancelled. Each tick delivers
  the on_result message.

  ## Examples

      Command.interval(100, :tick)
  """
  @spec interval(pos_integer(), term()) :: t()
  def interval(interval_ms, on_result) when is_integer(interval_ms) and interval_ms > 0 do
    %__MODULE__{
      type: :interval,
      payload: interval_ms,
      on_result: on_result
    }
  end

  @doc """
  Creates a file read command.

  Returns `{:ok, content}` or `{:error, reason}` wrapped in the on_result message.

  ## Examples

      Command.file_read("/path/to/file", :file_loaded)
      # Results in: {:file_loaded, {:ok, "contents"}}
      # or: {:file_loaded, {:error, :enoent}}
  """
  @spec file_read(Path.t(), term()) :: t()
  def file_read(path, on_result) when is_binary(path) do
    %__MODULE__{
      type: :file_read,
      payload: path,
      on_result: on_result
    }
  end

  @doc """
  Creates a send_after command that sends a message to a component after delay.

  Unlike timer which sends to the originating component, send_after
  can target any component.

  ## Examples

      Command.send_after(:other_component, :wake_up, 1000)
  """
  @spec send_after(atom(), term(), pos_integer()) :: t()
  def send_after(component_id, message, delay_ms)
      when is_atom(component_id) and is_integer(delay_ms) and delay_ms > 0 do
    %__MODULE__{
      type: :send_after,
      payload: {component_id, message, delay_ms},
      on_result: :send_after_complete
    }
  end

  @doc """
  Creates a quit command to request application shutdown.

  The runtime will initiate graceful shutdown, cleaning up all resources
  and restoring the terminal to its original state.

  ## Examples

      # Simple quit
      Command.quit()

      # Quit with reason
      Command.quit(:normal)
      Command.quit(:user_requested)
  """
  @spec quit(term()) :: t()
  def quit(reason \\ :normal) do
    %__MODULE__{
      type: :quit,
      payload: reason,
      on_result: nil
    }
  end

  @doc """
  Creates a no-op command.

  Useful for conditional commands where you might not need an effect.

  ## Examples

      cmd = if should_fetch?, do: Command.timer(100, :fetch), else: Command.none()
  """
  @spec none() :: t()
  def none do
    %__MODULE__{
      type: :none,
      payload: nil,
      on_result: nil
    }
  end

  @doc """
  Sets a timeout for command execution.

  If the command takes longer than the timeout, it's cancelled
  and an error message is sent.

  ## Examples

      Command.file_read(path, :loaded)
      |> Command.with_timeout(5000)
  """
  @spec with_timeout(t(), pos_integer()) :: t()
  def with_timeout(%__MODULE__{} = command, timeout_ms)
      when is_integer(timeout_ms) and timeout_ms > 0 do
    %{command | timeout: timeout_ms}
  end

  @doc """
  Validates a command structure.

  Returns `:ok` if valid, `{:error, reason}` otherwise.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{type: :none}), do: :ok

  def validate(%__MODULE__{type: :timer, payload: delay}) when is_integer(delay) and delay > 0,
    do: :ok

  def validate(%__MODULE__{type: :interval, payload: interval})
      when is_integer(interval) and interval > 0,
      do: :ok

  def validate(%__MODULE__{type: :file_read, payload: path}) when is_binary(path), do: :ok

  def validate(%__MODULE__{type: :send_after, payload: {id, _msg, delay}})
      when is_atom(id) and is_integer(delay) and delay > 0,
      do: :ok

  def validate(%__MODULE__{type: :quit}), do: :ok

  def validate(%__MODULE__{type: type, payload: payload}) do
    {:error, {:invalid_command, type, payload}}
  end

  def validate(_), do: {:error, :not_a_command}

  @doc """
  Checks if a term is a valid command.
  """
  @spec valid?(term()) :: boolean()
  def valid?(term), do: validate(term) == :ok

  @doc """
  Assigns a unique ID to a command for tracking.
  """
  @spec assign_id(t()) :: t()
  def assign_id(%__MODULE__{} = command) do
    %{command | id: make_ref()}
  end
end
