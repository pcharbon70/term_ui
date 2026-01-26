defmodule TermUI.Input.LineReader do
  @moduledoc """
  Line-based input module for the `TextInput.Line` widget.

  This module provides line-oriented input using `IO.gets/1`, which enables
  shell line editing features. It is specifically designed for the `TextInput.Line`
  widget, where users enter free-form text and submit with Enter.

  > #### Not a Behaviour Implementation {: .info}
  >
  > Unlike `TermUI.Input.Raw` and `TermUI.Input.TTY`, this module does **not**
  > implement the `TermUI.Input` behaviour. It is a standalone utility module
  > for line-based input, not character-by-character polling. Use this module
  > directly when you need line input with shell editing; use the behaviour
  > implementations for immediate character input.

  ## When to Use LineReader

  Use `LineReader` when you need:
  - **Free-form text entry**: User types arbitrary text
  - **Shell line editing**: Backspace, cursor movement, etc.
  - **Submit on Enter**: Input is complete when user presses Enter

  Most TermUI widgets use character-by-character input (`Input.Raw` or `Input.TTY`)
  for immediate key response. Use `LineReader` only for text fields that benefit
  from shell editing.

  ## Security Considerations

  This module provides raw line input and does not perform sanitization:

  - **Input length**: No length limits are enforced by this module. The shell
    and terminal typically impose their own limits (commonly 4KB-128KB depending
    on configuration). If your application has specific length requirements,
    validate after reading. For concurrent usage, consider that each pending
    read could hold up to the shell's maximum line length in memory.

  - **Input sanitization**: Input is returned as-is from `IO.gets/1`. The
    application is responsible for any sanitization (escaping, filtering
    special characters, etc.) appropriate for its use case.

  - **No injection protection**: This module does not filter or escape input.
    If the input will be used in shell commands, SQL queries, or other
    security-sensitive contexts, proper escaping must be applied by the caller.

  - **Blocking I/O**: `read_line/1` blocks indefinitely until input is received.
    This could be exploited in a DoS scenario if many concurrent reads are
    started. For server applications, consider using timeouts at a higher level.

  ## Shell Line Editing Features

  When using `LineReader`, the shell provides (depending on terminal):
  - **Backspace**: Delete character before cursor
  - **Delete**: Delete character at cursor
  - **Left/Right arrows**: Move cursor within line
  - **Home/End**: Jump to start/end of line
  - **Ctrl+A/E**: Jump to start/end (Emacs-style)
  - **Ctrl+K**: Kill to end of line
  - **History**: Up/Down for command history (if shell supports)

  These features are provided by the shell, not by TermUI. The exact features
  available depend on the user's shell configuration.

  ## Usage

      # Simple line input
      case LineReader.read_line("Enter name: ") do
        {:ok, name} -> process_name(name)
        :eof -> handle_eof()
      end

      # With validation
      validator = fn input ->
        if String.length(input) >= 3 do
          :ok
        else
          {:error, "Name must be at least 3 characters"}
        end
      end

      case LineReader.read_line("Enter name: ", validator) do
        {:ok, name} -> process_name(name)
        {:error, reason} -> show_error(reason)
        :eof -> handle_eof()
      end

  ## Comparison with Character Input

  | Feature | LineReader | Input.Raw/TTY |
  |---------|------------|---------------|
  | Input style | Line-based | Character-by-character |
  | Submit | Enter key | Immediate |
  | Editing | Shell-provided | Application-handled |
  | Use case | TextInput.Line | Menu, PickList, etc. |

  ## Important Notes

  - **Blocking**: `read_line/1` blocks until the user presses Enter or EOF
  - **No timeout**: Cannot interrupt or timeout the read
  - **Raw mode**: If running in raw mode, line editing may not work as expected
  - **TTY only**: Best used with the TTY backend for full shell editing support
  - **Error handling**: IO errors from `IO.gets/1` are converted to `:eof` for
    simplified error handling. Most callers don't need to distinguish between
    "stream ended" and "read error" scenarios.

  ## TextInput.Line Widget

  This module is the input backend for `TextInput.Line`. The widget:
  1. Displays a prompt and current value
  2. Calls `LineReader.read_line/1` to get user input
  3. Validates and processes the result

  For character-by-character text input with custom editing, use `TextInput`
  (without `.Line`) which uses `Input.Raw` or `Input.TTY`.
  """

  @typedoc """
  Result of a line read operation.

  - `{:ok, line}` - Successfully read a line (trimmed of trailing newline)
  - `:eof` - End of input stream
  """
  @type read_result :: {:ok, String.t()} | :eof

  @typedoc """
  Result of a validated line read operation.

  - `{:ok, value}` - Line was read and validation passed
  - `{:error, reason}` - Line was read but validation failed
  - `:eof` - End of input stream
  """
  @type validated_result :: {:ok, term()} | {:error, term()} | :eof

  @typedoc """
  Validator function for input validation.

  Should accept the trimmed input string and return:
  - `:ok` - Input is valid (original string is returned)
  - `{:ok, transformed}` - Input is valid, return transformed value
  - `{:error, reason}` - Input is invalid with given reason
  """
  @type validator :: (String.t() -> :ok | {:ok, term()} | {:error, term()})

  @doc """
  Reads a line of input with an optional prompt.

  Displays the prompt (if provided) and reads a complete line of input from
  stdin. The trailing newline is automatically trimmed from the result.

  ## Parameters

  - `prompt` - Optional prompt string to display (default: `""`)

  ## Returns

  - `{:ok, line}` - The line that was entered (without trailing newline)
  - `:eof` - End of input stream

  ## Examples

      # With prompt
      {:ok, name} = LineReader.read_line("Enter your name: ")

      # Without prompt
      {:ok, input} = LineReader.read_line()

      # Handling EOF
      case LineReader.read_line("Input: ") do
        {:ok, line} -> process(line)
        :eof -> shutdown()
      end

  ## Notes

  - This function blocks until the user presses Enter or EOF is received
  - Empty input (just Enter) returns `{:ok, ""}`
  - The prompt is written to stdout before reading
  """
  @spec read_line(String.t()) :: read_result()
  def read_line(prompt \\ "") do
    case IO.gets(prompt) do
      :eof ->
        :eof

      {:error, _reason} ->
        :eof

      line when is_binary(line) ->
        {:ok, String.trim_trailing(line, "\n")}
    end
  end

  @doc """
  Reads a line of input with validation.

  Displays the prompt, reads a line, and validates it using the provided
  validator function. The validator receives the trimmed input and should
  return validation status.

  ## Parameters

  - `prompt` - Prompt string to display
  - `validator` - Function to validate the input

  ## Validator Function

  The validator should accept a string and return one of:
  - `:ok` - Input is valid, return original string
  - `{:ok, transformed}` - Input is valid, return transformed value
  - `{:error, reason}` - Input is invalid

  ## Returns

  - `{:ok, value}` - Input was valid (original or transformed value)
  - `{:error, reason}` - Input was invalid
  - `:eof` - End of input stream

  ## Examples

      # Simple validation
      validator = fn input ->
        if String.length(input) > 0, do: :ok, else: {:error, "Cannot be empty"}
      end
      {:ok, name} = LineReader.read_line("Name: ", validator)

      # Transforming validation (parse to integer)
      int_validator = fn input ->
        case Integer.parse(input) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "Must be a valid integer"}
        end
      end
      {:ok, age} = LineReader.read_line("Age: ", int_validator)

      # Regex validation
      email_validator = fn input ->
        if String.match?(input, ~r/^[^@]+@[^@]+\\.[^@]+$/) do
          :ok
        else
          {:error, "Invalid email format"}
        end
      end
      {:ok, email} = LineReader.read_line("Email: ", email_validator)

  ## Notes

  - Validation is only performed if a line was successfully read
  - EOF bypasses validation and returns `:eof` directly
  - The validator receives the trimmed input (no trailing newline)
  """
  @spec read_line(String.t(), validator()) :: validated_result()
  def read_line(prompt, validator) when is_function(validator, 1) do
    case read_line(prompt) do
      {:ok, line} ->
        case validator.(line) do
          :ok -> {:ok, line}
          {:ok, transformed} -> {:ok, transformed}
          {:error, reason} -> {:error, reason}
        end

      :eof ->
        :eof
    end
  end
end
