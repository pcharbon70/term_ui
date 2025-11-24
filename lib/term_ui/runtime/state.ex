defmodule TermUI.Runtime.State do
  @moduledoc """
  State struct for the Runtime GenServer.

  Contains all runtime state including:
  - Root component module and state
  - Component registry
  - Message queue
  - Render configuration
  - Focus tracking
  - Shutdown status
  """

  alias TermUI.MessageQueue

  @type t :: %__MODULE__{
          root_module: module(),
          root_state: term(),
          message_queue: MessageQueue.t(),
          render_interval: pos_integer(),
          dirty: boolean(),
          focused_component: atom(),
          components: %{atom() => component_entry()},
          pending_commands: %{reference() => command_entry()},
          shutting_down: boolean(),
          terminal_started: boolean(),
          buffer_manager: pid() | nil,
          dimensions: {pos_integer(), pos_integer()} | nil,
          input_reader: pid() | nil
        }

  @type component_entry :: %{
          module: module(),
          state: term()
        }

  @type command_entry :: %{
          component_id: atom(),
          command: term()
        }

  defstruct [
    :root_module,
    :root_state,
    :message_queue,
    :render_interval,
    :dirty,
    :focused_component,
    :components,
    :pending_commands,
    :shutting_down,
    :terminal_started,
    :buffer_manager,
    :dimensions,
    :input_reader
  ]
end
