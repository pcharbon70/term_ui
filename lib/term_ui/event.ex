defmodule TermUI.Event do
  @moduledoc """
  Event type definitions for TermUI.

  Events represent user input from the terminal: keyboard presses,
  mouse actions, and focus changes. Events are routed to components
  by the EventRouter based on focus state and position.

  ## Event Types

  - `Key` - Keyboard input (key press, char input)
  - `Mouse` - Mouse actions (click, move, scroll)
  - `Focus` - Focus changes (gained, lost)
  - `Custom` - Application-defined events

  ## Examples

      # Key event
      event = Event.key(:enter)
      event = Event.key(:a, char: "a")
      event = Event.key(:c, modifiers: [:ctrl])

      # Mouse event
      event = Event.mouse(:click, :left, 10, 20)
      event = Event.mouse(:move, nil, 15, 25)

      # Focus event
      event = Event.focus(:gained)
      event = Event.focus(:lost)
  """

  # Key Event

  defmodule Key do
    @moduledoc """
    Keyboard input event.

    Represents a key press with optional character and modifiers.
    """

    @type t :: %__MODULE__{
            key: atom(),
            char: String.t() | nil,
            modifiers: [atom()],
            timestamp: integer()
          }

    defstruct key: nil,
              char: nil,
              modifiers: [],
              timestamp: 0

    @doc """
    Creates a new key event.
    """
    def new(key, opts \\ []) do
      %__MODULE__{
        key: key,
        char: Keyword.get(opts, :char),
        modifiers: Keyword.get(opts, :modifiers, []),
        timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond))
      }
    end
  end

  # Mouse Event

  defmodule Mouse do
    @moduledoc """
    Mouse input event.

    Represents mouse actions with position and button info.
    """

    @type action :: :click | :double_click | :move | :drag | :scroll_up | :scroll_down | :press | :release
    @type button :: :left | :middle | :right | nil

    @type t :: %__MODULE__{
            action: action(),
            button: button(),
            x: integer(),
            y: integer(),
            modifiers: [atom()],
            timestamp: integer()
          }

    defstruct action: :click,
              button: :left,
              x: 0,
              y: 0,
              modifiers: [],
              timestamp: 0

    @doc """
    Creates a new mouse event.
    """
    def new(action, button, x, y, opts \\ []) do
      %__MODULE__{
        action: action,
        button: button,
        x: x,
        y: y,
        modifiers: Keyword.get(opts, :modifiers, []),
        timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond))
      }
    end
  end

  # Focus Event

  defmodule Focus do
    @moduledoc """
    Focus change event.

    Sent to components when they gain or lose focus.
    """

    @type action :: :gained | :lost

    @type t :: %__MODULE__{
            action: action(),
            timestamp: integer()
          }

    defstruct action: :gained,
              timestamp: 0

    @doc """
    Creates a new focus event.
    """
    def new(action, opts \\ []) when action in [:gained, :lost] do
      %__MODULE__{
        action: action,
        timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond))
      }
    end
  end

  # Custom Event

  defmodule Custom do
    @moduledoc """
    Application-defined custom event.

    For app-specific events not covered by standard types.
    """

    @type t :: %__MODULE__{
            name: atom(),
            payload: term(),
            timestamp: integer()
          }

    defstruct name: nil,
              payload: nil,
              timestamp: 0

    @doc """
    Creates a new custom event.
    """
    def new(name, payload \\ nil, opts \\ []) do
      %__MODULE__{
        name: name,
        payload: payload,
        timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond))
      }
    end
  end

  # Convenience constructors

  @doc """
  Creates a key event.

  ## Examples

      Event.key(:enter)
      Event.key(:a, char: "a")
      Event.key(:c, modifiers: [:ctrl])
  """
  @spec key(atom(), keyword()) :: Key.t()
  def key(key, opts \\ []) do
    Key.new(key, opts)
  end

  @doc """
  Creates a mouse event.

  ## Examples

      Event.mouse(:click, :left, 10, 20)
      Event.mouse(:move, nil, x, y)
  """
  @spec mouse(Mouse.action(), Mouse.button(), integer(), integer(), keyword()) :: Mouse.t()
  def mouse(action, button, x, y, opts \\ []) do
    Mouse.new(action, button, x, y, opts)
  end

  @doc """
  Creates a focus event.

  ## Examples

      Event.focus(:gained)
      Event.focus(:lost)
  """
  @spec focus(Focus.action(), keyword()) :: Focus.t()
  def focus(action, opts \\ []) do
    Focus.new(action, opts)
  end

  @doc """
  Creates a custom event.

  ## Examples

      Event.custom(:submit, %{value: "hello"})
  """
  @spec custom(atom(), term(), keyword()) :: Custom.t()
  def custom(name, payload \\ nil, opts \\ []) do
    Custom.new(name, payload, opts)
  end

  # Type checks

  @doc "Returns true if event is a key event"
  @spec key?(term()) :: boolean()
  def key?(%Key{}), do: true
  def key?(_), do: false

  @doc "Returns true if event is a mouse event"
  @spec mouse?(term()) :: boolean()
  def mouse?(%Mouse{}), do: true
  def mouse?(_), do: false

  @doc "Returns true if event is a focus event"
  @spec focus?(term()) :: boolean()
  def focus?(%Focus{}), do: true
  def focus?(_), do: false

  @doc "Returns true if event is a custom event"
  @spec custom?(term()) :: boolean()
  def custom?(%Custom{}), do: true
  def custom?(_), do: false

  @doc """
  Returns the event type as an atom.
  """
  @spec type(Key.t() | Mouse.t() | Focus.t() | Custom.t()) :: :key | :mouse | :focus | :custom
  def type(%Key{}), do: :key
  def type(%Mouse{}), do: :mouse
  def type(%Focus{}), do: :focus
  def type(%Custom{}), do: :custom

  @doc """
  Checks if a modifier is present in the event.
  """
  @spec has_modifier?(Key.t() | Mouse.t(), atom()) :: boolean()
  def has_modifier?(%{modifiers: modifiers}, modifier) do
    modifier in modifiers
  end
end
