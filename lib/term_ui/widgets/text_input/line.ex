defmodule TermUI.Widgets.TextInput.Line do
  @moduledoc """
  Line-based text input widget using shell line editing.

  This widget provides a simple text input experience using `IO.gets/1` through
  the `TermUI.Input.LineReader` module. Unlike the standard `TextInput` widget
  which handles character-by-character input, this widget delegates to the shell
  for line editing, providing familiar shell features.

  ## When to Use TextInput.Line

  Use `TextInput.Line` when you need:
  - **Free-form text entry**: User types arbitrary text and submits with Enter
  - **Shell line editing**: Backspace, cursor movement, command history
  - **Simple input flow**: Just prompt → read → validate → done

  Use the standard `TextInput` widget when you need:
  - Character-by-character input handling
  - Custom key bindings or input transformations
  - Real-time validation as the user types
  - Multi-line text editing

  ## Shell Line Editing Features

  When using `TextInput.Line`, the shell provides (depending on terminal):
  - **Backspace**: Delete character before cursor
  - **Delete**: Delete character at cursor
  - **Left/Right arrows**: Move cursor within line
  - **Home/End**: Jump to start/end of line
  - **Ctrl+A/E**: Jump to start/end (Emacs-style)
  - **Ctrl+K**: Kill to end of line
  - **Up/Down arrows**: Command history (if shell supports)

  These features are provided by the shell, not by TermUI.

  ## TTY Mode Compatibility

  This widget is designed for TTY mode where shell line editing is available.
  It also works in raw mode, but the shell editing features may be limited.

  > #### Standard TextInput Works in TTY Mode {: .info}
  >
  > The standard `TermUI.Widgets.TextInput` widget works perfectly in TTY mode
  > for character-by-character input. Use `TextInput.Line` only when you
  > specifically want shell line editing features.

  ## Usage

      # Create input props
      props = TextInput.Line.new(
        prompt: "Enter name: ",
        label: "User Name",
        placeholder: "Type your name"
      )

      # Initialize state
      {:ok, state} = TextInput.Line.init(props)

      # Read input (blocks until Enter)
      case TextInput.Line.read(state) do
        {:ok, value, new_state} ->
          IO.puts("You entered: \#{value}")
          new_state

        {:error, reason, new_state} ->
          IO.puts("Invalid input: \#{reason}")
          new_state

        {:eof, new_state} ->
          IO.puts("EOF received")
          new_state
      end

  ## With Validation

      validator = fn input ->
        if String.length(input) >= 3 do
          :ok
        else
          {:error, "Name must be at least 3 characters"}
        end
      end

      props = TextInput.Line.new(
        prompt: "Enter name: ",
        validator: validator
      )

  ## Comparison with TextInput

  | Feature | TextInput.Line | TextInput |
  |---------|----------------|-----------|
  | Input style | Line-based (Enter to submit) | Character-by-character |
  | Line editing | Shell-provided | Widget-handled |
  | Real-time validation | No | Yes |
  | Multi-line | No | Yes (optional) |
  | Custom key bindings | No | Yes |
  | Blocking | Yes (blocks during read) | No (event-driven) |
  """

  alias TermUI.Input.LineReader

  @typedoc """
  TextInput.Line state structure.

  - `:prompt` - Text displayed before input cursor
  - `:value` - Current or last entered value
  - `:label` - Optional label displayed above input
  - `:validator` - Optional validation function
  - `:placeholder` - Text shown when value is empty
  - `:error` - Current validation error message, if any
  """
  @type t :: %__MODULE__{
          prompt: String.t(),
          value: String.t(),
          label: String.t() | nil,
          validator: validator() | nil,
          placeholder: String.t(),
          error: String.t() | nil
        }

  @typedoc """
  Validator function type.

  Should return:
  - `:ok` - Input is valid
  - `{:ok, transformed}` - Input is valid, use transformed value
  - `{:error, reason}` - Input is invalid
  """
  @type validator :: (String.t() -> :ok | {:ok, term()} | {:error, term()})

  @typedoc """
  Result of a read operation.

  - `{:ok, value, state}` - Successfully read and validated input
  - `{:error, reason, state}` - Read succeeded but validation failed
  - `{:eof, state}` - End of input stream
  """
  @type read_result ::
          {:ok, term(), t()}
          | {:error, term(), t()}
          | {:eof, t()}

  defstruct prompt: "",
            value: "",
            label: nil,
            validator: nil,
            placeholder: "",
            error: nil

  @doc """
  Creates new TextInput.Line props.

  ## Options

  - `:prompt` - Text to display before input (default: "")
  - `:value` - Initial value (default: "")
  - `:label` - Optional label to display above input (default: nil)
  - `:validator` - Validation function (default: nil)
  - `:placeholder` - Text shown when value is empty (default: "")

  ## Examples

      # Simple input
      TextInput.Line.new(prompt: "Name: ")

      # With label and placeholder
      TextInput.Line.new(
        prompt: "> ",
        label: "Enter your name",
        placeholder: "Type here..."
      )

      # With validation
      TextInput.Line.new(
        prompt: "Age: ",
        validator: fn input ->
          case Integer.parse(input) do
            {age, ""} when age > 0 -> {:ok, age}
            _ -> {:error, "Please enter a valid positive number"}
          end
        end
      )
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    %{
      prompt: Keyword.get(opts, :prompt, ""),
      value: Keyword.get(opts, :value, ""),
      label: Keyword.get(opts, :label),
      validator: Keyword.get(opts, :validator),
      placeholder: Keyword.get(opts, :placeholder, "")
    }
  end

  @doc """
  Initializes TextInput.Line state from props.

  ## Examples

      props = TextInput.Line.new(prompt: "Name: ")
      {:ok, state} = TextInput.Line.init(props)
  """
  @spec init(map()) :: {:ok, t()}
  def init(props) do
    state = %__MODULE__{
      prompt: props.prompt,
      value: props.value,
      label: props.label,
      validator: props.validator,
      placeholder: props.placeholder,
      error: nil
    }

    {:ok, state}
  end

  @doc """
  Reads a line of input from the user.

  This function blocks until the user presses Enter or EOF is received.
  The shell provides line editing features during input.

  If a validator is configured, it will be applied to the input. The result
  depends on validation:

  - Valid input: `{:ok, value, new_state}` - value may be transformed by validator
  - Invalid input: `{:error, reason, new_state}` - error is stored in state
  - EOF: `{:eof, new_state}`

  ## Examples

      case TextInput.Line.read(state) do
        {:ok, value, state} ->
          IO.puts("Got: \#{value}")
          state

        {:error, reason, state} ->
          IO.puts("Error: \#{reason}")
          state

        {:eof, state} ->
          IO.puts("EOF")
          state
      end
  """
  @spec read(t()) :: read_result()
  def read(%__MODULE__{} = state) do
    case state.validator do
      nil ->
        # No validator, use simple read
        case LineReader.read_line(state.prompt) do
          {:ok, line} ->
            new_state = %{state | value: line, error: nil}
            {:ok, line, new_state}

          :eof ->
            {:eof, state}
        end

      validator when is_function(validator, 1) ->
        # Has validator, use read_line/2
        case LineReader.read_line(state.prompt, validator) do
          {:ok, value} ->
            # Value may be transformed by validator
            string_value = if is_binary(value), do: value, else: inspect(value)
            new_state = %{state | value: string_value, error: nil}
            {:ok, value, new_state}

          {:error, reason} ->
            error_msg = if is_binary(reason), do: reason, else: inspect(reason)
            new_state = %{state | error: error_msg}
            {:error, reason, new_state}

          :eof ->
            {:eof, state}
        end
    end
  end

  @doc """
  Gets the current value.

  ## Examples

      value = TextInput.Line.get_value(state)
  """
  @spec get_value(t()) :: String.t()
  def get_value(%__MODULE__{value: value}), do: value

  @doc """
  Sets the value programmatically.

  This does not trigger validation. Use `read/1` to get validated input.

  ## Examples

      state = TextInput.Line.set_value(state, "new value")
  """
  @spec set_value(t(), String.t()) :: t()
  def set_value(%__MODULE__{} = state, value) when is_binary(value) do
    %{state | value: value, error: nil}
  end

  @doc """
  Clears the current value and any error.

  ## Examples

      state = TextInput.Line.clear(state)
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = state) do
    %{state | value: "", error: nil}
  end

  @doc """
  Gets the current error message, if any.

  ## Examples

      case TextInput.Line.get_error(state) do
        nil -> IO.puts("No error")
        error -> IO.puts("Error: \#{error}")
      end
  """
  @spec get_error(t()) :: String.t() | nil
  def get_error(%__MODULE__{error: error}), do: error

  @doc """
  Checks if the widget has an error.

  ## Examples

      if TextInput.Line.has_error?(state) do
        IO.puts("Please fix the error")
      end
  """
  @spec has_error?(t()) :: boolean()
  def has_error?(%__MODULE__{error: error}), do: error != nil

  @doc """
  Clears the current error.

  ## Examples

      state = TextInput.Line.clear_error(state)
  """
  @spec clear_error(t()) :: t()
  def clear_error(%__MODULE__{} = state) do
    %{state | error: nil}
  end

  @doc """
  Gets the label, if any.

  ## Examples

      label = TextInput.Line.get_label(state)
  """
  @spec get_label(t()) :: String.t() | nil
  def get_label(%__MODULE__{label: label}), do: label

  @doc """
  Gets the prompt.

  ## Examples

      prompt = TextInput.Line.get_prompt(state)
  """
  @spec get_prompt(t()) :: String.t()
  def get_prompt(%__MODULE__{prompt: prompt}), do: prompt

  @doc """
  Gets the placeholder text.

  ## Examples

      placeholder = TextInput.Line.get_placeholder(state)
  """
  @spec get_placeholder(t()) :: String.t()
  def get_placeholder(%__MODULE__{placeholder: placeholder}), do: placeholder
end
