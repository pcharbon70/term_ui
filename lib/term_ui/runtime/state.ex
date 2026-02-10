defmodule TermUI.Runtime.State do
  @moduledoc """
  State struct for the Runtime GenServer.

  Contains all runtime state including:
  - Root component module and state
  - Component registry
  - Message queue
  - Event queue (bounded, prevents DoS)
  - Render configuration
  - Focus tracking
  - Shutdown status
  - Backend selection and capabilities
  - Input handler (Raw or TTY mode)
  """

  alias TermUI.EventQueue
  alias TermUI.MessageQueue

  @type backend_mode :: :raw | :tty | nil

  @type capabilities :: %{
          optional(:colors) => :true_color | :color_256 | :color_16 | :monochrome,
          optional(:unicode) => boolean(),
          optional(:dimensions) => {pos_integer(), pos_integer()} | nil,
          optional(:terminal) => boolean(),
          optional(:raw_mode_error) => term()
        }

  @type t :: %__MODULE__{
          root_module: module(),
          root_state: term(),
          message_queue: MessageQueue.t(),
          event_queue: EventQueue.t(),
          render_interval: pos_integer(),
          dirty: boolean(),
          focused_component: atom(),
          components: %{atom() => component_entry()},
          pending_commands: %{reference() => command_entry()},
          shutting_down: boolean(),
          terminal_started: boolean(),
          buffer_manager: pid() | nil,
          dimensions: {pos_integer(), pos_integer()} | nil,
          input_reader: pid() | nil,
          backend_mode: backend_mode(),
          backend: module() | nil,
          backend_state: term() | nil,
          capabilities: capabilities() | nil,
          input_handler: module() | nil,
          input_state: term() | nil,
          logger_handler_config: map() | nil
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
    :event_queue,
    :render_interval,
    :dirty,
    :focused_component,
    :components,
    :pending_commands,
    :shutting_down,
    :terminal_started,
    :buffer_manager,
    :dimensions,
    :input_reader,
    backend_mode: nil,
    backend: nil,
    backend_state: nil,
    capabilities: nil,
    input_handler: nil,
    input_state: nil,
    logger_handler_config: nil
  ]
end
