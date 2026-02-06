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

  ## Blocking I/O Behavior (Architectural Note)

  Unlike other TermUI widgets which are event-driven, `TextInput.Line` uses
  **blocking I/O** when reading input. This is an intentional design choice:

  1. **Why blocking?** Shell line editing requires the terminal to be in line
     mode, where the shell buffers input until Enter is pressed. This is
     fundamentally different from raw mode's character-by-character input.

  2. **Process implications:** When `read/1` or `handle_focus/1` is called,
     the calling process blocks until input is complete. This means:
     - The widget cannot respond to other events during input
     - UI updates (like animations) will pause
     - Other processes are unaffected

  3. **Best practices:**
     - Use `TextInput.Line` for simple, sequential input flows
     - For concurrent input handling, spawn a separate process for input
     - For real-time UI during input, use the standard `TextInput` widget

  This behavior is intentional and will not change. The blocking nature enables
  shell line editing features that are not possible with event-driven input.
  """

  alias TermUI.Input.LineReader

  import TermUI.Component.RenderNode
  alias TermUI.Renderer.Style
  alias TermUI.Theme

  @typedoc """
  TextInput.Line state structure.

  - `:prompt` - Text displayed before input cursor
  - `:value` - Current or last entered value
  - `:label` - Optional label displayed above input
  - `:validator` - Optional validation function
  - `:placeholder` - Text shown when value is empty
  - `:error` - Current validation error message, if any
  - `:focused` - Whether the widget currently has focus
  - `:on_blur` - Optional callback when widget loses focus or completes input
  """
  @type t :: %__MODULE__{
          prompt: String.t(),
          value: String.t(),
          label: String.t() | nil,
          validator: validator() | nil,
          placeholder: String.t(),
          error: String.t() | nil,
          focused: boolean(),
          on_blur: (t() -> any()) | nil
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
  - `{:cancelled, state}` - Input was cancelled (Ctrl+C)
  - `{:eof, state}` - End of input stream
  """
  @type read_result ::
          {:ok, term(), t()}
          | {:error, term(), t()}
          | {:cancelled, t()}
          | {:eof, t()}

  defstruct prompt: "",
            value: "",
            label: nil,
            validator: nil,
            placeholder: "",
            error: nil,
            focused: false,
            on_blur: nil

  @doc """
  Creates new TextInput.Line props.

  ## Options

  - `:prompt` - Text to display before input (default: "")
  - `:value` - Initial value (default: "")
  - `:label` - Optional label to display above input (default: nil)
  - `:validator` - Validation function (default: nil)
  - `:placeholder` - Text shown when value is empty (default: "")
  - `:on_blur` - Callback when widget loses focus or completes input (default: nil)

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
      placeholder: Keyword.get(opts, :placeholder, ""),
      on_blur: Keyword.get(opts, :on_blur)
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
      error: nil,
      focused: false,
      on_blur: Map.get(props, :on_blur)
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
  def read(%__MODULE__{validator: nil} = state) do
    read_without_validator(state)
  end

  def read(%__MODULE__{validator: validator} = state) when is_function(validator, 1) do
    read_with_validator(state)
  end

  defp read_without_validator(state) do
    case LineReader.read_line(state.prompt) do
      {:ok, line} -> {:ok, line, %{state | value: line, error: nil}}
      :eof -> {:eof, state}
    end
  end

  defp read_with_validator(state) do
    state.prompt
    |> LineReader.read_line(state.validator)
    |> handle_validated_read_result(state)
  end

  defp handle_validated_read_result({:ok, value}, state) do
    string_value = to_string_value(value)
    {:ok, value, %{state | value: string_value, error: nil}}
  end

  defp handle_validated_read_result({:error, reason}, state) do
    error_msg = to_string_value(reason)
    {:error, reason, %{state | error: error_msg}}
  end

  defp handle_validated_read_result(:eof, state), do: {:eof, state}

  defp to_string_value(value) when is_binary(value), do: value
  defp to_string_value(value), do: inspect(value)

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

  # ----------------------------------------------------------------------------
  # Focus Behavior
  # ----------------------------------------------------------------------------

  @doc """
  Handles focus gain by initiating a line read.

  When the widget gains focus, this function:
  1. Sets the focused state to true
  2. Initiates a blocking line read
  3. Returns the result with updated state
  4. Calls on_blur callback if configured

  The function blocks until the user presses Enter or cancels with Ctrl+C.

  ## Return Values

  - `{:ok, value, state}` - Successfully read and validated input
  - `{:error, reason, state}` - Validation failed
  - `{:cancelled, state}` - User cancelled with Ctrl+C (EOF)

  ## Examples

      {:ok, state} = TextInput.Line.init(TextInput.Line.new(prompt: "> "))
      result = TextInput.Line.handle_focus(state)
      # User types "hello" and presses Enter
      # => {:ok, "hello", %TextInput.Line{value: "hello", focused: false, ...}}
  """
  @spec handle_focus(t()) :: read_result()
  def handle_focus(%__MODULE__{} = state) do
    # Set focused state
    state = %{state | focused: true}

    # Perform the read (blocks until Enter or Ctrl+C)
    result = do_focused_read(state)

    # Clear focus and call on_blur callback
    result = unfocus_result(result)
    call_on_blur(result)

    result
  end

  # Performs the read while focused (no validator)
  defp do_focused_read(%{validator: nil} = state) do
    case LineReader.read_line(state.prompt) do
      {:ok, line} -> {:ok, line, %{state | value: line, error: nil}}
      :eof -> {:cancelled, state}
    end
  end

  # Performs the read while focused (with validator)
  defp do_focused_read(%{validator: validator} = state) when is_function(validator, 1) do
    state.prompt
    |> LineReader.read_line(validator)
    |> handle_focused_read_result(state)
  end

  defp handle_focused_read_result({:ok, value}, state) do
    string_value = to_string_value(value)
    {:ok, value, %{state | value: string_value, error: nil}}
  end

  defp handle_focused_read_result({:error, reason}, state) do
    error_msg = to_string_value(reason)
    {:error, reason, %{state | error: error_msg}}
  end

  defp handle_focused_read_result(:eof, state), do: {:cancelled, state}

  # Clear focused state in result
  defp unfocus_result({:ok, value, state}), do: {:ok, value, %{state | focused: false}}
  defp unfocus_result({:error, reason, state}), do: {:error, reason, %{state | focused: false}}
  defp unfocus_result({:cancelled, state}), do: {:cancelled, %{state | focused: false}}

  # Call on_blur callback if configured (with error protection)
  defp call_on_blur({_, _, state}) when is_function(state.on_blur, 1) do
    state.on_blur.(state)
  rescue
    e ->
      require Logger
      Logger.error("TextInput.Line on_blur callback error: #{inspect(e)}")
  end

  defp call_on_blur({:cancelled, state}) when is_function(state.on_blur, 1) do
    state.on_blur.(state)
  rescue
    e ->
      require Logger
      Logger.error("TextInput.Line on_blur callback error: #{inspect(e)}")
  end

  defp call_on_blur(_), do: :ok

  @doc """
  Checks if the widget is currently focused.

  ## Examples

      TextInput.Line.focused?(state)  # => true or false
  """
  @spec focused?(t()) :: boolean()
  def focused?(%__MODULE__{focused: focused}), do: focused

  @doc """
  Sets the focus state directly.

  Typically you should use `handle_focus/1` instead, which initiates a read.
  This function is useful for testing or manual focus management.

  ## Examples

      state = TextInput.Line.set_focused(state, true)
  """
  @spec set_focused(t(), boolean()) :: t()
  def set_focused(%__MODULE__{} = state, focused) when is_boolean(focused) do
    %{state | focused: focused}
  end

  @doc """
  Clears focus and calls the on_blur callback if configured.

  ## Examples

      state = TextInput.Line.blur(state)
  """
  @spec blur(t()) :: t()
  def blur(%__MODULE__{} = state) do
    new_state = %{state | focused: false}

    if is_function(state.on_blur, 1) do
      try do
        state.on_blur.(new_state)
      rescue
        e ->
          require Logger
          Logger.error("TextInput.Line on_blur callback error: #{inspect(e)}")
      end
    end

    new_state
  end

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  @doc """
  Renders the widget state as a render node tree.

  The render output consists of:
  1. Label (if provided) - displayed on first line
  2. Prompt + value (or placeholder if empty) - the input line
  3. Error message (if present) - displayed below in error styling

  ## Examples

      state = %TextInput.Line{prompt: "> ", value: "hello", label: "Name"}
      node = TextInput.Line.render(state)

  ## Styling

  - Label: default foreground color
  - Prompt: default foreground color
  - Value: default foreground color
  - Placeholder: dim/muted style (bright_black)
  - Error: error style (red)
  """
  @spec render(t()) :: TermUI.Component.RenderNode.t()
  def render(%__MODULE__{} = state) do
    parts = []

    # 1. Add label if present
    parts =
      if state.label do
        [render_label(state.label) | parts]
      else
        parts
      end

    # 2. Add prompt + value/placeholder line
    parts = [render_input_line(state) | parts]

    # 3. Add error if present
    parts =
      if state.error do
        [render_error(state.error) | parts]
      else
        parts
      end

    # Reverse to get correct order and build vertical stack
    parts = Enum.reverse(parts)

    case parts do
      [single] -> single
      multiple -> stack(:vertical, multiple)
    end
  end

  # Renders the label line
  defp render_label(label) do
    text(label)
  end

  # Renders the prompt + value or placeholder
  defp render_input_line(state) do
    display_text =
      if state.value == "" and state.placeholder != "" do
        # Show placeholder with muted style
        placeholder_style = Style.new(fg: :bright_black)

        stack(:horizontal, [
          text(state.prompt),
          text(state.placeholder, placeholder_style)
        ])
      else
        # Show prompt + value
        text(state.prompt <> state.value)
      end

    display_text
  end

  # Renders the error message
  defp render_error(error) do
    error_style = Style.new() |> Style.fg(Theme.get_semantic(:error))
    text(error, error_style)
  end
end
