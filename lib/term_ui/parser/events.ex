defmodule TermUI.Parser.Events do
  @moduledoc """
  Event struct definitions for parsed terminal input.
  """

  defmodule KeyEvent do
    @moduledoc """
    Represents a keyboard input event.

    ## Fields
    - `key` - The key pressed (atom for special keys, string for characters)
    - `modifiers` - List of modifiers held (`:ctrl`, `:alt`, `:shift`, `:meta`)
    """
    @type t :: %__MODULE__{
            key: atom() | String.t(),
            modifiers: [atom()]
          }

    defstruct key: nil, modifiers: []
  end

  defmodule MouseEvent do
    @moduledoc """
    Represents a mouse input event.

    ## Fields
    - `action` - `:press`, `:release`, or `:motion`
    - `button` - `:left`, `:middle`, `:right`, `:wheel_up`, `:wheel_down`, or `:none`
    - `x` - Column (1-indexed)
    - `y` - Row (1-indexed)
    - `modifiers` - List of modifiers held
    """
    @type t :: %__MODULE__{
            action: :press | :release | :motion,
            button: atom(),
            x: pos_integer(),
            y: pos_integer(),
            modifiers: [atom()]
          }

    defstruct action: :press, button: :left, x: 1, y: 1, modifiers: []
  end

  defmodule PasteEvent do
    @moduledoc """
    Represents bracketed paste content.

    ## Fields
    - `content` - The pasted text
    """
    @type t :: %__MODULE__{
            content: String.t()
          }

    defstruct content: ""
  end

  defmodule FocusEvent do
    @moduledoc """
    Represents a focus change event.

    ## Fields
    - `focused` - `true` if terminal gained focus, `false` if lost
    """
    @type t :: %__MODULE__{
            focused: boolean()
          }

    defstruct focused: true
  end

  defmodule ResizeEvent do
    @moduledoc """
    Represents a terminal resize event.

    ## Fields
    - `rows` - New row count
    - `cols` - New column count
    """
    @type t :: %__MODULE__{
            rows: pos_integer(),
            cols: pos_integer()
          }

    defstruct rows: 24, cols: 80
  end
end
