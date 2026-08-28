defmodule TermUI.Backend.InputBuffer do
  @moduledoc """
  Shared input buffer management for terminal backends.

  This module provides secure input buffer handling with:
  - Size limits to prevent memory exhaustion
  - Rate-limited logging to prevent log flooding
  - Consistent behavior across backends

  ## Security

  The input buffer protects against memory exhaustion attacks where
  malformed input streams send unterminated escape sequences. Without
  protection, the buffer would grow indefinitely.

  ### Buffer Size Limits

  - Maximum buffer size: 1024 bytes
  - Keep size on truncation: 256 bytes

  The 256-byte keep size preserves potential partial escape sequences
  (typical sequences are 8-20 bytes, max CSI is ~100 bytes).

  ### Rate-Limited Logging

  Buffer overflow warnings are rate-limited to prevent log flooding
  attacks. Maximum one warning every 5 seconds per backend instance.

  ## Usage

  Backends should use this module instead of implementing their own
  buffer management:

      # In your backend module
      alias TermUI.Backend.InputBuffer

      # Appending data
      new_buffer = InputBuffer.append(state.input_buffer, data)

      # Applying limit (returns {buffer, overflow_occurred?})
      {limited_buffer, overflowed} = InputBuffer.apply_limit(new_buffer)

      # Or use the combined function that handles state
      new_state = InputBuffer.append_with_limit(state, data, :input_buffer)
  """

  require Logger

  # Maximum buffer size before truncation (1KB)
  @max_buffer_size 1024

  # Number of bytes to keep when truncating (preserves partial sequences)
  @keep_size 256

  # Minimum time between overflow warnings (5 seconds in milliseconds)
  @warning_interval_ms 5_000

  # ETS table for tracking last warning times (created on first use)
  @warning_table :term_ui_input_buffer_warnings

  # Dialyzer: Functions return specific types or constants
  @dialyzer {:nowarn_function, max_size: 0, keep_size: 0, ensure_table_exists: 0}

  @doc """
  Returns the maximum buffer size allowed.

  ## Examples

      iex> TermUI.Backend.InputBuffer.max_size()
      1024
  """
  @spec max_size() :: pos_integer()
  def max_size, do: @max_buffer_size

  @doc """
  Returns the number of bytes kept when truncating.

  ## Examples

      iex> TermUI.Backend.InputBuffer.keep_size()
      256
  """
  @spec keep_size() :: pos_integer()
  def keep_size, do: @keep_size

  @doc """
  Appends data to a buffer and returns the new buffer.

  This is a simple append without limit checking. Use `apply_limit/2`
  or `append_with_limit/4` for protected appending.

  ## Parameters

  - `buffer` - The existing buffer (binary)
  - `data` - Data to append (binary)

  ## Returns

  The combined buffer.

  ## Examples

      iex> TermUI.Backend.InputBuffer.append("hello", " world")
      "hello world"
  """
  @spec append(binary(), binary()) :: binary()
  def append(buffer, data) when is_binary(buffer) and is_binary(data) do
    buffer <> data
  end

  @doc """
  Applies the buffer size limit, truncating if necessary.

  If the buffer exceeds the maximum size, it is truncated to keep only
  the most recent bytes (to preserve potential partial escape sequences).

  ## Parameters

  - `buffer` - The buffer to check (binary)
  - `opts` - Options:
    - `:source` - Identifier for rate-limited logging (default: `:unknown`)
    - `:log` - Whether to log overflow (default: `true`)

  ## Returns

  Tuple of `{limited_buffer, overflowed?}`.

  ## Examples

      iex> {buffer, false} = TermUI.Backend.InputBuffer.apply_limit("short")
      iex> buffer
      "short"

      iex> long = String.duplicate("x", 2000)
      iex> {buffer, true} = TermUI.Backend.InputBuffer.apply_limit(long, source: :test)
      iex> byte_size(buffer)
      256
  """
  @spec apply_limit(binary(), keyword()) :: {binary(), boolean()}
  def apply_limit(buffer, opts \\ []) when is_binary(buffer) do
    buffer_size = byte_size(buffer)

    if buffer_size > @max_buffer_size do
      # Keep only the most recent bytes
      actual_keep = min(@keep_size, buffer_size)
      truncated = binary_part(buffer, buffer_size - actual_keep, actual_keep)

      # Rate-limited logging
      source = Keyword.get(opts, :source, :unknown)
      should_log = Keyword.get(opts, :log, true)

      if should_log do
        maybe_log_overflow(source, buffer_size, actual_keep)
      end

      {truncated, true}
    else
      {buffer, false}
    end
  end

  @doc """
  Appends data to a state's buffer field with limit protection.

  This is a convenience function that:
  1. Appends data to the specified buffer field
  2. Applies the size limit
  3. Returns the updated state

  ## Parameters

  - `state` - Map or struct containing the buffer
  - `data` - Data to append (binary)
  - `field` - The field name containing the buffer (atom)
  - `opts` - Options passed to `apply_limit/2`

  ## Returns

  The updated state with the new buffer value.

  ## Examples

      iex> state = %{input_buffer: "partial"}
      iex> new_state = TermUI.Backend.InputBuffer.append_with_limit(state, "[A", :input_buffer)
      iex> new_state.input_buffer
      "partial[A"
  """
  @spec append_with_limit(map(), binary(), atom(), keyword()) :: map()
  def append_with_limit(state, data, field, opts \\ []) when is_map(state) and is_atom(field) do
    current = Map.get(state, field, "")
    new_buffer = append(current, data)
    {limited, _overflowed} = apply_limit(new_buffer, opts)
    Map.put(state, field, limited)
  end

  # ===========================================================================
  # Rate-Limited Logging
  # ===========================================================================

  # Logs a warning if enough time has passed since the last warning.
  @spec maybe_log_overflow(term(), pos_integer(), pos_integer()) :: :ok
  defp maybe_log_overflow(source, original_size, keep_size) do
    now = System.monotonic_time(:millisecond)

    case get_last_warning_time(source) do
      nil ->
        # First overflow for this source
        set_last_warning_time(source, now)
        do_log_overflow(source, original_size, keep_size)

      last_time when now - last_time >= @warning_interval_ms ->
        # Enough time has passed
        set_last_warning_time(source, now)
        do_log_overflow(source, original_size, keep_size)

      _last_time ->
        # Too soon, skip logging
        :ok
    end
  end

  defp do_log_overflow(source, original_size, keep_size) do
    Logger.warning(
      "Input buffer overflow (#{original_size} bytes) in #{inspect(source)}, " <>
        "truncating to #{keep_size} bytes"
    )
  end

  # Gets the last warning time for a source from ETS.
  @spec get_last_warning_time(term()) :: integer() | nil
  defp get_last_warning_time(source) do
    ensure_table_exists()

    case :ets.lookup(@warning_table, source) do
      [{^source, time}] -> time
      [] -> nil
    end
  end

  # Sets the last warning time for a source in ETS.
  @spec set_last_warning_time(term(), integer()) :: true
  defp set_last_warning_time(source, time) do
    ensure_table_exists()
    :ets.insert(@warning_table, {source, time})
  end

  # Ensures the ETS table exists.
  @spec ensure_table_exists() :: :ok
  defp ensure_table_exists do
    case :ets.whereis(@warning_table) do
      :undefined ->
        # Create the table - it might race with another process
        try do
          :ets.new(@warning_table, [:set, :public, :named_table])
        rescue
          ArgumentError ->
            # Table already exists (race condition), that's fine
            :ok
        end

      _tid ->
        :ok
    end

    :ok
  end

  @doc """
  Clears the rate limit state (useful for testing).

  ## Examples

      iex> TermUI.Backend.InputBuffer.clear_rate_limits()
      :ok
  """
  @spec clear_rate_limits() :: :ok
  def clear_rate_limits do
    case :ets.whereis(@warning_table) do
      :undefined -> :ok
      _tid -> :ets.delete_all_objects(@warning_table)
    end

    :ok
  end
end
