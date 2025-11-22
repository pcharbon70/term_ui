defmodule TermUI.Clipboard do
  @moduledoc """
  Clipboard integration for TermUI applications.

  Provides clipboard writing via OSC 52 escape sequences and
  paste event handling. Clipboard operations work across terminals
  that support these features.

  ## Usage

      # Write to clipboard
      Clipboard.write("text to copy")

      # Check OSC 52 support
      if Clipboard.osc52_supported?() do
        Clipboard.write(content)
      end

      # Enable bracketed paste mode
      IO.write(Clipboard.bracketed_paste_on())
  """

  # OSC 52 clipboard sequence
  # Format: ESC ] 52 ; <target> ; <base64-data> ST
  # Target: c = clipboard, p = primary selection
  @osc52_prefix "\e]52;"
  @osc52_suffix "\e\\"

  # Bracketed paste mode
  @bracketed_paste_on "\e[?2004h"
  @bracketed_paste_off "\e[?2004l"

  # Paste markers
  @paste_start "\e[200~"
  @paste_end "\e[201~"

  @doc """
  Returns escape sequence to enable bracketed paste mode.
  """
  @spec bracketed_paste_on() :: String.t()
  def bracketed_paste_on, do: @bracketed_paste_on

  @doc """
  Returns escape sequence to disable bracketed paste mode.
  """
  @spec bracketed_paste_off() :: String.t()
  def bracketed_paste_off, do: @bracketed_paste_off

  @doc """
  Returns the paste start marker sequence.
  """
  @spec paste_start_marker() :: String.t()
  def paste_start_marker, do: @paste_start

  @doc """
  Returns the paste end marker sequence.
  """
  @spec paste_end_marker() :: String.t()
  def paste_end_marker, do: @paste_end

  @doc """
  Generates OSC 52 escape sequence to write to clipboard.

  Returns the escape sequence string that should be written to
  the terminal to set the clipboard content.

  ## Options

  - `:target` - Clipboard target: `:clipboard` (default) or `:primary`

  ## Examples

      iex> Clipboard.write_sequence("hello")
      "\\e]52;c;aGVsbG8=\\e\\\\"

      iex> Clipboard.write_sequence("test", target: :primary)
      "\\e]52;p;dGVzdA==\\e\\\\"
  """
  @spec write_sequence(String.t(), keyword()) :: String.t()
  def write_sequence(content, opts \\ []) do
    target = Keyword.get(opts, :target, :clipboard)
    target_char = target_to_char(target)
    encoded = Base.encode64(content)

    @osc52_prefix <> target_char <> ";" <> encoded <> @osc52_suffix
  end

  @doc """
  Writes content to the system clipboard via OSC 52.

  This writes the escape sequence directly to the terminal.
  Returns `:ok` on success.

  ## Options

  - `:target` - Clipboard target: `:clipboard` (default) or `:primary`
  """
  @spec write(String.t(), keyword()) :: :ok
  def write(content, opts \\ []) do
    sequence = write_sequence(content, opts)
    IO.write(sequence)
    :ok
  end

  @doc """
  Checks if OSC 52 clipboard is likely supported.

  This is a heuristic check based on terminal type. Some terminals
  support OSC 52 but don't advertise it; others advertise but block it.

  Known supporting terminals:
  - xterm (with allowWindowOps)
  - Alacritty
  - Kitty
  - WezTerm
  - iTerm2
  - foot
  """
  @spec osc52_supported?() :: boolean()
  def osc52_supported? do
    term = System.get_env("TERM", "")
    term_program = System.get_env("TERM_PROGRAM", "")

    cond do
      # Known good terminals
      String.contains?(term_program, "iTerm") -> true
      String.contains?(term_program, "Alacritty") -> true
      String.contains?(term_program, "WezTerm") -> true
      System.get_env("KITTY_WINDOW_ID") != nil -> true
      # xterm and derivatives often support it
      String.starts_with?(term, "xterm") -> true
      # foot terminal
      term == "foot" or term == "foot-extra" -> true
      # Conservative default - assume not supported
      true -> false
    end
  end

  @doc """
  Generates OSC 52 sequence to clear the clipboard.
  """
  @spec clear_sequence(keyword()) :: String.t()
  def clear_sequence(opts \\ []) do
    target = Keyword.get(opts, :target, :clipboard)
    target_char = target_to_char(target)

    # Empty base64 clears the selection
    @osc52_prefix <> target_char <> ";" <> @osc52_suffix
  end

  @doc """
  Clears the system clipboard via OSC 52.
  """
  @spec clear(keyword()) :: :ok
  def clear(opts \\ []) do
    sequence = clear_sequence(opts)
    IO.write(sequence)
    :ok
  end

  # Private functions

  defp target_to_char(:clipboard), do: "c"
  defp target_to_char(:primary), do: "p"
  defp target_to_char(:secondary), do: "s"
  defp target_to_char(target) when is_binary(target), do: target
end

defmodule TermUI.Clipboard.PasteAccumulator do
  @moduledoc """
  Accumulates bracketed paste content.

  Handles the state machine for collecting paste content between
  paste start and end markers. Supports timeout for incomplete pastes.
  """

  @type t :: %__MODULE__{
          accumulating: boolean(),
          content: String.t(),
          started_at: integer() | nil
        }

  defstruct accumulating: false,
            content: "",
            started_at: nil

  @doc """
  Creates a new paste accumulator.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Starts accumulating paste content.
  """
  @spec start(t()) :: t()
  def start(%__MODULE__{} = acc) do
    %{acc | accumulating: true, content: "", started_at: System.monotonic_time(:millisecond)}
  end

  @doc """
  Adds content to the accumulator.
  """
  @spec add(t(), String.t()) :: t()
  def add(%__MODULE__{accumulating: true} = acc, content) do
    %{acc | content: acc.content <> content}
  end

  def add(%__MODULE__{} = acc, _content), do: acc

  @doc """
  Completes accumulation and returns the content.
  """
  @spec complete(t()) :: {String.t(), t()}
  def complete(%__MODULE__{accumulating: true, content: content} = _acc) do
    {content, new()}
  end

  def complete(%__MODULE__{} = acc), do: {"", acc}

  @doc """
  Checks if currently accumulating.
  """
  @spec accumulating?(t()) :: boolean()
  def accumulating?(%__MODULE__{accumulating: acc}), do: acc

  @doc """
  Checks if paste has timed out.

  Default timeout is 5000ms.
  """
  @spec timed_out?(t(), integer()) :: boolean()
  def timed_out?(%__MODULE__{accumulating: false}, _timeout), do: false

  def timed_out?(%__MODULE__{started_at: started_at}, timeout) do
    now = System.monotonic_time(:millisecond)
    now - started_at >= timeout
  end

  @doc """
  Resets the accumulator, discarding any partial content.
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{} = _acc), do: new()
end
