defmodule TermUI.Clipboard.Selection do
  @moduledoc """
  Selection state management for clipboard operations.

  Tracks text selection with start and end positions, supporting
  selection expansion with Shift+arrow keys and clearing on
  navigation without Shift.

  ## Usage

      # Create selection
      selection = Selection.new()

      # Start selection at cursor
      selection = Selection.start(selection, 5)

      # Extend selection
      selection = Selection.extend(selection, 10)

      # Get selected range
      {start, finish} = Selection.range(selection)

      # Extract content
      selected_text = Selection.extract(selection, "Hello World")
  """

  @type t :: %__MODULE__{
          start_pos: integer() | nil,
          end_pos: integer() | nil,
          anchor: integer() | nil,
          active: boolean()
        }

  defstruct start_pos: nil,
            end_pos: nil,
            anchor: nil,
            active: false

  @doc """
  Creates a new empty selection.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Starts a new selection at the given position.

  This sets the anchor point for the selection.
  """
  @spec start(t(), integer()) :: t()
  def start(%__MODULE__{} = _selection, position) do
    %__MODULE__{
      start_pos: position,
      end_pos: position,
      anchor: position,
      active: true
    }
  end

  @doc """
  Extends the selection to a new position.

  The selection extends from the anchor to the new position.
  """
  @spec extend(t(), integer()) :: t()
  def extend(%__MODULE__{active: false} = selection, position) do
    start(selection, position)
  end

  def extend(%__MODULE__{anchor: anchor} = selection, position) do
    {start_pos, end_pos} = if position < anchor, do: {position, anchor}, else: {anchor, position}

    %{selection | start_pos: start_pos, end_pos: end_pos}
  end

  @doc """
  Clears the selection.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = _selection) do
    new()
  end

  @doc """
  Checks if there is an active selection.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{active: active}), do: active

  @doc """
  Checks if the selection is empty (start equals end).
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{active: false}), do: true
  def empty?(%__MODULE__{start_pos: start, end_pos: finish}), do: start == finish

  @doc """
  Returns the selection range as {start, end}.

  Returns `nil` if no selection is active.
  """
  @spec range(t()) :: {integer(), integer()} | nil
  def range(%__MODULE__{active: false}), do: nil
  def range(%__MODULE__{start_pos: start, end_pos: finish}), do: {start, finish}

  @doc """
  Returns the length of the selection.
  """
  @spec length(t()) :: integer()
  def length(%__MODULE__{active: false}), do: 0
  def length(%__MODULE__{start_pos: start, end_pos: finish}), do: finish - start

  @doc """
  Extracts selected content from a string.

  Returns empty string if no selection is active.
  """
  @spec extract(t(), String.t()) :: String.t()
  def extract(%__MODULE__{active: false}, _text), do: ""

  def extract(%__MODULE__{start_pos: start, end_pos: finish}, text) do
    String.slice(text, start, finish - start)
  end

  @doc """
  Checks if a position is within the selection.
  """
  @spec contains?(t(), integer()) :: boolean()
  def contains?(%__MODULE__{active: false}, _position), do: false

  def contains?(%__MODULE__{start_pos: start, end_pos: finish}, position) do
    position >= start and position < finish
  end

  @doc """
  Moves the selection by a delta.

  Both start and end positions are adjusted.
  """
  @spec move(t(), integer()) :: t()
  def move(%__MODULE__{active: false} = selection, _delta), do: selection

  def move(%__MODULE__{start_pos: start, end_pos: finish, anchor: anchor} = selection, delta) do
    %{selection | start_pos: start + delta, end_pos: finish + delta, anchor: anchor + delta}
  end

  @doc """
  Expands the selection in a direction.

  Direction can be `:left`, `:right`, `:word_left`, `:word_right`,
  `:line_start`, `:line_end`, `:all`.
  """
  @spec expand(t(), atom(), String.t(), integer()) :: t()
  def expand(%__MODULE__{} = selection, direction, text, cursor_pos) do
    new_pos = calculate_expansion(direction, text, cursor_pos)

    if active?(selection) do
      extend(selection, new_pos)
    else
      selection
      |> start(cursor_pos)
      |> extend(new_pos)
    end
  end

  @doc """
  Selects all text.
  """
  @spec select_all(t(), String.t()) :: t()
  def select_all(%__MODULE__{} = _selection, text) do
    len = String.length(text)

    %__MODULE__{
      start_pos: 0,
      end_pos: len,
      anchor: 0,
      active: true
    }
  end

  @doc """
  Selects a word at the given position.
  """
  @spec select_word(t(), String.t(), integer()) :: t()
  def select_word(%__MODULE__{} = _selection, text, position) do
    {word_start, word_end} = find_word_bounds(text, position)

    %__MODULE__{
      start_pos: word_start,
      end_pos: word_end,
      anchor: word_start,
      active: true
    }
  end

  # Private functions

  defp calculate_expansion(:left, _text, cursor_pos) do
    max(0, cursor_pos - 1)
  end

  defp calculate_expansion(:right, text, cursor_pos) do
    min(String.length(text), cursor_pos + 1)
  end

  defp calculate_expansion(:word_left, text, cursor_pos) do
    find_word_boundary_left(text, cursor_pos)
  end

  defp calculate_expansion(:word_right, text, cursor_pos) do
    find_word_boundary_right(text, cursor_pos)
  end

  defp calculate_expansion(:line_start, _text, _cursor_pos) do
    0
  end

  defp calculate_expansion(:line_end, text, _cursor_pos) do
    String.length(text)
  end

  defp calculate_expansion(:all, text, _cursor_pos) do
    String.length(text)
  end

  defp find_word_boundary_left(text, position) do
    text
    |> String.slice(0, position)
    |> String.reverse()
    |> find_word_start()
    |> then(&(position - &1))
  end

  defp find_word_boundary_right(text, position) do
    text
    |> String.slice(position, String.length(text) - position)
    |> find_word_end()
    |> then(&(position + &1))
  end

  defp find_word_start(reversed_text) do
    # Skip whitespace, then find word characters
    reversed_text
    |> String.graphemes()
    |> Enum.reduce_while({0, :skip_space}, fn char, {count, state} ->
      cond do
        state == :skip_space and whitespace?(char) ->
          {:cont, {count + 1, :skip_space}}

        state == :skip_space and word_char?(char) ->
          {:cont, {count + 1, :in_word}}

        state == :in_word and word_char?(char) ->
          {:cont, {count + 1, :in_word}}

        true ->
          {:halt, {count, :done}}
      end
    end)
    |> elem(0)
  end

  defp find_word_end(text) do
    text
    |> String.graphemes()
    |> Enum.reduce_while({0, :skip_space}, fn char, {count, state} ->
      cond do
        state == :skip_space and whitespace?(char) ->
          {:cont, {count + 1, :skip_space}}

        state == :skip_space and word_char?(char) ->
          {:cont, {count + 1, :in_word}}

        state == :in_word and word_char?(char) ->
          {:cont, {count + 1, :in_word}}

        true ->
          {:halt, {count, :done}}
      end
    end)
    |> elem(0)
  end

  defp find_word_bounds(text, position) do
    # Find start of word
    word_start =
      text
      |> String.slice(0, position)
      |> String.reverse()
      |> then(fn prefix ->
        len =
          prefix
          |> String.graphemes()
          |> Enum.take_while(&word_char?/1)
          |> Kernel.length()

        position - len
      end)

    # Find end of word
    word_end =
      text
      |> String.slice(position, String.length(text) - position)
      |> then(fn suffix ->
        len =
          suffix
          |> String.graphemes()
          |> Enum.take_while(&word_char?/1)
          |> Kernel.length()

        position + len
      end)

    {word_start, word_end}
  end

  defp word_char?(char) do
    String.match?(char, ~r/\w/)
  end

  defp whitespace?(char) do
    String.match?(char, ~r/\s/)
  end
end
