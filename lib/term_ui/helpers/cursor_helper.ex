defmodule TermUI.Helpers.CursorHelper do
  @moduledoc """
  Helper functions for cursor navigation within lists.

  This module provides convenience functions for managing cursor positions
  in widgets with selectable items (menus, lists, tables, tree views, etc.).

  ## Usage

      import TermUI.Helpers.CursorHelper

      # Move cursor down with wrapping
      new_cursor = move_down(cursor, 1, item_count, wrap: true)

      # Move cursor up with clamping
      new_cursor = move_up(cursor, 1, item_count)

      # Clamp cursor to valid range
      new_cursor = clamp_cursor(cursor, 0, item_count - 1)

  ## Common Patterns

  All functions work with 0-based cursor indices. The `max` parameter
  is typically `length(items) - 1` for the last valid index.
  """

  @doc """
  Moves the cursor down (towards higher indices).

  ## Parameters

  - `cursor` - Current cursor position (0-based)
  - `step` - Number of positions to move (default: 1)
  - `max` - Maximum valid cursor position (inclusive)
  - `opts` - Options:
    - `:wrap` - If true, wraps from max to 0 (default: false)

  ## Examples

      iex> move_down(0, 1, 4)
      1

      iex> move_down(4, 1, 4)  # At max, clamped
      4

      iex> move_down(4, 1, 4, wrap: true)  # At max, wraps to 0
      0

      iex> move_down(2, 3, 4)  # Move 3 positions, clamped to max
      4
  """
  @spec move_down(non_neg_integer(), non_neg_integer(), non_neg_integer(), keyword()) ::
          non_neg_integer()
  def move_down(cursor, step \\ 1, max, opts \\ [])
      when is_integer(cursor) and is_integer(step) and is_integer(max) do
    wrap = Keyword.get(opts, :wrap, false)
    new_pos = cursor + step

    cond do
      new_pos > max and wrap -> rem(new_pos, max + 1)
      new_pos > max -> max
      true -> new_pos
    end
  end

  @doc """
  Moves the cursor up (towards lower indices).

  ## Parameters

  - `cursor` - Current cursor position (0-based)
  - `step` - Number of positions to move (default: 1)
  - `max` - Maximum valid cursor position (used for wrapping)
  - `opts` - Options:
    - `:wrap` - If true, wraps from 0 to max (default: false)

  ## Examples

      iex> move_up(2, 1, 4)
      1

      iex> move_up(0, 1, 4)  # At 0, clamped
      0

      iex> move_up(0, 1, 4, wrap: true)  # At 0, wraps to max
      4

      iex> move_up(1, 3, 4)  # Move 3 positions, clamped to 0
      0
  """
  @spec move_up(non_neg_integer(), non_neg_integer(), non_neg_integer(), keyword()) ::
          non_neg_integer()
  def move_up(cursor, step \\ 1, max, opts \\ [])
      when is_integer(cursor) and is_integer(step) and is_integer(max) do
    wrap = Keyword.get(opts, :wrap, false)
    new_pos = cursor - step

    cond do
      new_pos < 0 and wrap -> max + 1 + new_pos
      new_pos < 0 -> 0
      true -> new_pos
    end
  end

  @doc """
  Clamps the cursor to valid bounds.

  Ensures cursor is within [min, max] range.

  ## Parameters

  - `cursor` - Current cursor position
  - `min` - Minimum valid position (default: 0)
  - `max` - Maximum valid position

  ## Examples

      iex> clamp_cursor(5, 0, 3)
      3

      iex> clamp_cursor(-2, 0, 3)
      0

      iex> clamp_cursor(2, 0, 3)
      2
  """
  @spec clamp_cursor(integer(), integer(), integer()) :: integer()
  def clamp_cursor(cursor, min \\ 0, max) when is_integer(cursor) do
    cursor
    |> max(min)
    |> min(max)
  end

  @doc """
  Wraps cursor position within valid range.

  Unlike clamp, wrap treats the range as circular.

  ## Parameters

  - `cursor` - Current cursor position (can be negative or > max)
  - `min` - Minimum valid position (default: 0)
  - `max` - Maximum valid position

  ## Examples

      iex> wrap_cursor(5, 0, 3)  # 5 wraps to 1 (5 mod 4 = 1)
      1

      iex> wrap_cursor(-1, 0, 3)  # -1 wraps to 3
      3

      iex> wrap_cursor(4, 0, 3)  # 4 wraps to 0
      0
  """
  @spec wrap_cursor(integer(), integer(), integer()) :: integer()
  def wrap_cursor(cursor, min \\ 0, max) when is_integer(cursor) do
    range = max - min + 1

    if range <= 0 do
      min
    else
      result = rem(cursor - min, range)

      if result < 0 do
        min + range + result
      else
        min + result
      end
    end
  end

  @doc """
  Finds the next valid cursor position, skipping invalid positions.

  Useful for skipping separators or disabled items in menus.

  ## Parameters

  - `cursor` - Current cursor position
  - `direction` - `:up` or `:down`
  - `max` - Maximum valid position
  - `valid?` - Function that returns true if position is valid
  - `opts` - Options:
    - `:wrap` - If true, wraps at boundaries (default: false)
    - `:max_attempts` - Maximum positions to try (default: max + 1)

  ## Examples

      # Skip disabled items (positions 1 and 2)
      valid? = fn pos -> pos not in [1, 2] end
      move_to_next_valid(0, :down, 4, valid?)
      # => 3 (skips 1 and 2)
  """
  @spec move_to_next_valid(
          non_neg_integer(),
          :up | :down,
          non_neg_integer(),
          (non_neg_integer() -> boolean()),
          keyword()
        ) :: non_neg_integer() | nil
  def move_to_next_valid(cursor, direction, max, valid?, opts \\ []) do
    wrap = Keyword.get(opts, :wrap, false)
    max_attempts = Keyword.get(opts, :max_attempts, max + 1)

    move_fn =
      case direction do
        :down -> &move_down(&1, 1, max, wrap: wrap)
        :up -> &move_up(&1, 1, max, wrap: wrap)
      end

    find_next_valid(cursor, move_fn, valid?, max_attempts, cursor)
  end

  defp find_next_valid(_cursor, _move_fn, _valid?, 0, _start), do: nil

  defp find_next_valid(cursor, move_fn, valid?, attempts, start) do
    next = move_fn.(cursor)

    cond do
      next == start and attempts < start + 1 -> nil
      valid?.(next) -> next
      true -> find_next_valid(next, move_fn, valid?, attempts - 1, start)
    end
  end

  @doc """
  Moves cursor to first valid position from the beginning.

  ## Parameters

  - `max` - Maximum valid position
  - `valid?` - Function that returns true if position is valid

  ## Examples

      # Find first non-disabled item
      valid? = fn pos -> pos not in [0, 1] end
      first_valid(4, valid?)
      # => 2
  """
  @spec first_valid(non_neg_integer(), (non_neg_integer() -> boolean())) ::
          non_neg_integer() | nil
  def first_valid(max, valid?) do
    Enum.find(0..max, valid?)
  end

  @doc """
  Moves cursor to last valid position from the end.

  ## Parameters

  - `max` - Maximum valid position
  - `valid?` - Function that returns true if position is valid

  ## Examples

      # Find last non-disabled item
      valid? = fn pos -> pos not in [3, 4] end
      last_valid(4, valid?)
      # => 2
  """
  @spec last_valid(non_neg_integer(), (non_neg_integer() -> boolean())) ::
          non_neg_integer() | nil
  def last_valid(max, valid?) do
    max..0//-1
    |> Enum.find(valid?)
  end
end
