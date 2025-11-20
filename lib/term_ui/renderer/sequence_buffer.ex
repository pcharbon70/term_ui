defmodule TermUI.Renderer.SequenceBuffer do
  @moduledoc """
  Batches escape sequences for efficient terminal output.

  Accumulates escape sequences and text in an iolist, then flushes to output
  when threshold is reached or frame completes. This reduces system call
  overhead and ensures atomic frame updates.

  ## Features

    * **Iolist accumulator** - Efficient append without copying
    * **Size threshold** - Auto-flush when buffer exceeds limit
    * **SGR combining** - Merges adjacent style sequences
    * **Statistics** - Tracks bytes written and flush count

  ## Usage

      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append(buffer, "\\e[1;31m")
      buffer = SequenceBuffer.append(buffer, "Hello")
      {data, buffer} = SequenceBuffer.flush(buffer)
      IO.binwrite(data)

  ## SGR Combining

  Adjacent SGR sequences are combined into a single sequence:

      # Instead of: ESC[1m ESC[31m ESC[4m
      # Produces:   ESC[1;31;4m

  This reduces output bytes and terminal parsing overhead.
  """

  alias TermUI.Renderer.Style

  @type t :: %__MODULE__{
          buffer: iolist(),
          size: non_neg_integer(),
          threshold: pos_integer(),
          pending_sgr: [String.t()],
          last_style: Style.t() | nil,
          total_bytes: non_neg_integer(),
          flush_count: non_neg_integer()
        }

  defstruct buffer: [],
            size: 0,
            threshold: 4096,
            pending_sgr: [],
            last_style: nil,
            total_bytes: 0,
            flush_count: 0

  @doc """
  Creates a new sequence buffer with default threshold (4KB).
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new sequence buffer with specified threshold.

  ## Options

    * `:threshold` - Flush threshold in bytes (default: 4096)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    threshold = Keyword.get(opts, :threshold, 4096)
    %__MODULE__{threshold: threshold}
  end

  @doc """
  Appends data to the buffer.

  Returns `{:ok, buffer}` normally, or `{:flush, data, buffer}` if the
  threshold was exceeded and an auto-flush occurred.
  """
  @spec append(t(), iodata()) :: {:ok, t()} | {:flush, iodata(), t()}
  def append(%__MODULE__{} = buffer, data) do
    data_size = IO.iodata_length(data)
    new_size = buffer.size + data_size

    # Prepend to buffer (will reverse on flush)
    new_buffer = %{buffer | buffer: [data | buffer.buffer], size: new_size}

    if new_size >= buffer.threshold do
      {flushed, reset_buffer} = flush(new_buffer)
      {:flush, flushed, reset_buffer}
    else
      {:ok, new_buffer}
    end
  end

  @doc """
  Appends data to the buffer, ignoring auto-flush result.

  Simpler API when you don't need to handle auto-flush immediately.
  """
  @spec append!(t(), iodata()) :: t()
  def append!(%__MODULE__{} = buffer, data) do
    case append(buffer, data) do
      {:ok, new_buffer} -> new_buffer
      {:flush, _data, new_buffer} -> new_buffer
    end
  end

  @doc """
  Appends a style, emitting SGR sequence with delta from last style.

  Only emits parameters that changed from the previous style.
  """
  @spec append_style(t(), Style.t()) :: t()
  def append_style(%__MODULE__{} = buffer, %Style{} = style) do
    sgr_params = style_to_sgr_params(style, buffer.last_style)

    if sgr_params == [] do
      # No change from last style
      buffer
    else
      sgr_sequence = build_sgr_sequence(sgr_params)
      new_buffer = append!(buffer, sgr_sequence)
      %{new_buffer | last_style: style}
    end
  end

  @doc """
  Appends multiple SGR parameters to be combined into a single sequence.

  Call `emit_pending_sgr/1` to output the combined sequence.
  """
  @spec add_sgr_param(t(), String.t()) :: t()
  def add_sgr_param(%__MODULE__{} = buffer, param) do
    %{buffer | pending_sgr: [param | buffer.pending_sgr]}
  end

  @doc """
  Emits any pending SGR parameters as a combined sequence.
  """
  @spec emit_pending_sgr(t()) :: t()
  def emit_pending_sgr(%__MODULE__{pending_sgr: []} = buffer), do: buffer

  def emit_pending_sgr(%__MODULE__{pending_sgr: params} = buffer) do
    # Reverse to maintain order
    sgr_sequence = build_sgr_sequence(Enum.reverse(params))
    new_buffer = append!(buffer, sgr_sequence)
    %{new_buffer | pending_sgr: []}
  end

  @doc """
  Flushes the buffer, returning accumulated data and resetting.

  Returns `{iodata, new_buffer}`.
  """
  @spec flush(t()) :: {iodata(), t()}
  def flush(%__MODULE__{} = buffer) do
    # Emit any pending SGR first
    buffer = emit_pending_sgr(buffer)

    # Reverse buffer to get correct order
    data = Enum.reverse(buffer.buffer)
    bytes = buffer.size

    new_buffer = %{
      buffer
      | buffer: [],
        size: 0,
        total_bytes: buffer.total_bytes + bytes,
        flush_count: buffer.flush_count + 1
    }

    {data, new_buffer}
  end

  @doc """
  Returns the current buffer size in bytes.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Returns whether the buffer is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Returns buffer statistics.

  Returns `{total_bytes, flush_count}`.
  """
  @spec stats(t()) :: {non_neg_integer(), non_neg_integer()}
  def stats(%__MODULE__{total_bytes: bytes, flush_count: count}) do
    {bytes, count}
  end

  @doc """
  Returns the current buffer contents as iodata without flushing.
  """
  @spec to_iodata(t()) :: iodata()
  def to_iodata(%__MODULE__{buffer: buffer}) do
    Enum.reverse(buffer)
  end

  @doc """
  Resets the style tracking, useful when style is explicitly reset.
  """
  @spec reset_style(t()) :: t()
  def reset_style(%__MODULE__{} = buffer) do
    %{buffer | last_style: nil}
  end

  @doc """
  Clears the buffer without flushing.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = buffer) do
    %{buffer | buffer: [], size: 0, pending_sgr: []}
  end

  # Private functions

  defp style_to_sgr_params(%Style{} = style, nil) do
    # No previous style - emit all
    build_full_sgr_params(style)
  end

  defp style_to_sgr_params(%Style{} = style, %Style{} = last) do
    # Emit only changed parameters
    params = []

    params =
      if style.fg != last.fg do
        [color_to_sgr(:fg, style.fg) | params]
      else
        params
      end

    params =
      if style.bg != last.bg do
        [color_to_sgr(:bg, style.bg) | params]
      else
        params
      end

    # Check for new attributes
    new_attrs = MapSet.difference(style.attrs, last.attrs)
    params = Enum.reduce(new_attrs, params, fn attr, acc -> [attr_to_sgr(attr) | acc] end)

    # Check for removed attributes (need reset)
    removed_attrs = MapSet.difference(last.attrs, style.attrs)

    params =
      Enum.reduce(removed_attrs, params, fn attr, acc -> [attr_off_sgr(attr) | acc] end)

    Enum.reverse(params) |> Enum.reject(&is_nil/1)
  end

  defp build_full_sgr_params(%Style{fg: fg, bg: bg, attrs: attrs}) do
    params = []
    params = if fg && fg != :default, do: [color_to_sgr(:fg, fg) | params], else: params
    params = if bg && bg != :default, do: [color_to_sgr(:bg, bg) | params], else: params
    params = Enum.reduce(attrs, params, fn attr, acc -> [attr_to_sgr(attr) | acc] end)
    Enum.reverse(params) |> Enum.reject(&is_nil/1)
  end

  defp build_sgr_sequence([]), do: []

  defp build_sgr_sequence(params) do
    ["\e[", Enum.intersperse(params, ";"), "m"]
  end

  defp color_to_sgr(:fg, :default), do: "39"
  defp color_to_sgr(:fg, :black), do: "30"
  defp color_to_sgr(:fg, :red), do: "31"
  defp color_to_sgr(:fg, :green), do: "32"
  defp color_to_sgr(:fg, :yellow), do: "33"
  defp color_to_sgr(:fg, :blue), do: "34"
  defp color_to_sgr(:fg, :magenta), do: "35"
  defp color_to_sgr(:fg, :cyan), do: "36"
  defp color_to_sgr(:fg, :white), do: "37"
  defp color_to_sgr(:fg, n) when is_integer(n), do: "38;5;#{n}"
  defp color_to_sgr(:fg, {r, g, b}), do: "38;2;#{r};#{g};#{b}"
  defp color_to_sgr(:fg, nil), do: nil

  defp color_to_sgr(:bg, :default), do: "49"
  defp color_to_sgr(:bg, :black), do: "40"
  defp color_to_sgr(:bg, :red), do: "41"
  defp color_to_sgr(:bg, :green), do: "42"
  defp color_to_sgr(:bg, :yellow), do: "43"
  defp color_to_sgr(:bg, :blue), do: "44"
  defp color_to_sgr(:bg, :magenta), do: "45"
  defp color_to_sgr(:bg, :cyan), do: "46"
  defp color_to_sgr(:bg, :white), do: "47"
  defp color_to_sgr(:bg, n) when is_integer(n), do: "48;5;#{n}"
  defp color_to_sgr(:bg, {r, g, b}), do: "48;2;#{r};#{g};#{b}"
  defp color_to_sgr(:bg, nil), do: nil

  defp attr_to_sgr(:bold), do: "1"
  defp attr_to_sgr(:dim), do: "2"
  defp attr_to_sgr(:italic), do: "3"
  defp attr_to_sgr(:underline), do: "4"
  defp attr_to_sgr(:blink), do: "5"
  defp attr_to_sgr(:reverse), do: "7"
  defp attr_to_sgr(:hidden), do: "8"
  defp attr_to_sgr(:strikethrough), do: "9"

  defp attr_off_sgr(:bold), do: "22"
  defp attr_off_sgr(:dim), do: "22"
  defp attr_off_sgr(:italic), do: "23"
  defp attr_off_sgr(:underline), do: "24"
  defp attr_off_sgr(:blink), do: "25"
  defp attr_off_sgr(:reverse), do: "27"
  defp attr_off_sgr(:hidden), do: "28"
  defp attr_off_sgr(:strikethrough), do: "29"
end
