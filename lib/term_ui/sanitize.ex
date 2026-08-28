defmodule TermUI.Sanitize do
  @moduledoc """
  Input sanitization for terminal escape sequence injection prevention.

  This module provides utilities to sanitize user input before rendering
  to prevent terminal escape sequence injection attacks.

  ## Security Model

  Terminal escape sequences can be maliciously injected into user input
  to:
  - Clear the screen
  - Modify terminal colors
  - Move cursor position
  - Execute arbitrary commands (in some terminals)
  - Hide/alter displayed content

  This module strips or neutralizes such sequences.

  ## Example

      iex> Sanitize.sanitize("\e[31mMalicious\e[0m")
      "[ESC][31mMalicious[ESC][0m"

      iex> Sanitize.sanitize("\e[31mMalicious\e[0m", escape: :remove)
      "Malicious"

      iex> Sanitize.sanitize("Normal text")
      "Normal text"
  """

  # NOTE: Defined as a function rather than a module attribute because compiled
  # Regex structs contain references that cannot be injected into function bodies.
  defp ansi_escape_pattern do
    ~r/(\x1b\[
         [0-9;:=?]*[
         \x40-\x7e]|
         \x1b\]
         [^\x07\x1b]*\x07|
         \x1b[^\x1b\x07]|
         \x07[\x05\x06]|
         \x00-\x08|\x0b-\x0c|\x0e-\x1f
       )/x
  end

  # Dialyzer: Functions return specific atom types
  @dialyzer {:nowarn_function, validate: 1}

  @doc """
  Sanitizes a string by processing terminal escape sequences.

  ## Options

  - `:escape` - How to handle ANSI escapes:
    - `:bracket` (default) - Replace with safe bracket notation
    - `:remove` - Remove entirely
    - `:keep` - Keep as-is (use with caution)

  - `:max_length` - Maximum string length (default: 10_000)

  ## Returns

  - Sanitized string
  - String truncated if exceeds max_length

  ## Examples

      iex> Sanitize.sanitize("\\e[31mRed\\e[0m")
      "[ESC][31mRed[ESC][0m"

      iex> Sanitize.sanitize("\\e[31mRed\\e[0m", escape: :remove)
      "Red"

      iex> Sanitize.sanitize(String.duplicate("a", 20000))
      String.duplicate("a", 10000)
  """
  @spec sanitize(binary(), keyword()) :: binary()
  def sanitize(input, opts \\ []) when is_binary(input) do
    escape_mode = Keyword.get(opts, :escape, :bracket)
    max_length = Keyword.get(opts, :max_length, 10_000)

    input
    |> truncate_length(max_length)
    |> sanitize_escapes(escape_mode)
  end

  @doc """
  Returns true if the string contains ANSI escape sequences.

  ## Examples

      iex> Sanitize.has_ansi?("\\e[31mRed")
      true

      iex> Sanitize.has_ansi?("Plain text")
      false
  """
  @spec has_ansi?(binary()) :: boolean()
  def has_ansi?(input) when is_binary(input) do
    Regex.match?(ansi_escape_pattern(), input)
  end

  @doc """
  Strips all ANSI escape sequences from the string.

  ## Examples

      iex> Sanitize.strip_ansi("\\e[31mRed\\e[0m")
      "Red"

      iex> Sanitize.strip_ansi("\\e[2J\\e[HHello")
      "Hello"
  """
  @spec strip_ansi(binary()) :: binary()
  def strip_ansi(input) when is_binary(input) do
    Regex.replace(ansi_escape_pattern(), input, "")
  end

  @doc """
  Validates that a string contains only safe printable characters.

  Returns `:ok` if safe, `{:error, reason}` if unsafe.

  ## Safety Rules

  - Only printable ASCII (32-126) and valid UTF-8
  - No control characters (except tab, newline, carriage return)
  - No ANSI escape sequences
  - No null bytes

  ## Examples

      iex> Sanitize.validate("Safe text")
      :ok

      iex> Sanitize.validate("\\e[31mUnsafe")
      {:error, :contains_ansi}

      iex> Sanitize.validate("Null\\x00byte")
      {:error, :contains_null_byte}
  """
  @spec validate(binary()) :: :ok | {:error, atom()}
  def validate(input) when is_binary(input) do
    cond do
      String.contains?(input, <<0>>) ->
        {:error, :contains_null_byte}

      has_ansi?(input) ->
        {:error, :contains_ansi}

      contains_unsafe_controls?(input) ->
        {:error, :contains_control_chars}

      true ->
        :ok
    end
  end

  @doc """
  Escapes a string for safe rendering by replacing dangerous sequences
  with safe bracket notation.

  This is useful when you want to visually indicate that escape
  sequences were present without allowing them to execute.

  ## Examples

      iex> Sanitize.escape_bracket("\\e[31m")
      "[ESC][31m"

      iex> Sanitize.escape_bracket("Normal")
      "Normal"
  """
  @spec escape_bracket(binary()) :: binary()
  def escape_bracket(input) when is_binary(input) do
    input
    |> String.replace("\e", "[ESC]")
    |> replace_control_chars()
  end

  # Private functions

  # Truncates string to max length
  defp truncate_length(input, max) when byte_size(input) > max do
    binary_part(input, 0, max)
  end

  defp truncate_length(input, _max), do: input

  # Sanitizes escapes based on mode
  defp sanitize_escapes(input, :bracket) do
    input
    |> String.replace("\e", "[ESC]")
    |> replace_control_chars()
  end

  defp sanitize_escapes(input, :remove) do
    Regex.replace(ansi_escape_pattern(), input, "")
  end

  defp sanitize_escapes(input, :keep), do: input

  # Replaces control characters with safe notation
  defp replace_control_chars(input) do
    input
    |> String.replace("\a", "[BEL]")
    |> String.replace("\b", "[BS]")
    |> String.replace("\v", "[VT]")
    |> String.replace("\f", "[FF]")
    |> String.replace("\e", "[ESC]")
  end

  # Checks for unsafe control characters
  # Allows: \t (9), \n (10), \r (13)
  # Rejects: \0-\8, \11-\12, \14-\31
  defp contains_unsafe_controls?(input) do
    # Collect bytes first, then check
    bytes = for <<byte <- input>>, do: byte

    Enum.any?(bytes, fn byte ->
      cond do
        byte in [0, 1, 2, 3, 4, 5, 6, 7, 8] -> true
        byte in [11, 12] -> true
        byte >= 14 and byte <= 31 -> true
        true -> false
      end
    end)
  end
end
