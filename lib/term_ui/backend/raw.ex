defmodule TermUI.Backend.Raw do
  @moduledoc false

  @behaviour TermUI.Backend

  alias TermUI.{ANSI, Clipboard, Frame}
  alias TermUI.Backend.{EventStream, Renderer}
  alias TermUI.Terminal.SizeDetector
  alias TermUI.{TerminalOutput, TermUtils}

  @all_mouse_off "\e[?1006l\e[?1003l\e[?1002l\e[?1000l"

  @type mouse_mode :: :none | :click | :drag | :all
  @type t :: %__MODULE__{
          size: TermUI.Backend.size(),
          alternate_screen: boolean(),
          mouse_mode: mouse_mode(),
          input_buffer: binary(),
          event_queue: [TermUI.Backend.event()],
          paste_state: map() | nil,
          input_reader: pid() | nil,
          last_frame: Frame.t() | nil,
          bracketed_paste: boolean(),
          focus_events: boolean()
        }

  @schema Zoi.struct(__MODULE__, %{
            size: Zoi.tuple({Zoi.integer(), Zoi.integer()}) |> Zoi.default({24, 80}),
            alternate_screen: Zoi.boolean() |> Zoi.default(true),
            mouse_mode: Zoi.enum([:none, :click, :drag, :all]) |> Zoi.default(:none),
            input_buffer: Zoi.string() |> Zoi.default(""),
            event_queue: Zoi.array() |> Zoi.default([]),
            paste_state: Zoi.any() |> Zoi.default(nil),
            input_reader: Zoi.any() |> Zoi.default(nil),
            last_frame: Zoi.any() |> Zoi.default(nil),
            bracketed_paste: Zoi.boolean() |> Zoi.default(true),
            focus_events: Zoi.boolean() |> Zoi.default(true)
          })

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  @spec init(keyword()) :: {:ok, t()} | {:error, term()}
  def init(opts) do
    with {:ok, size} <- SizeDetector.detect(size: Keyword.get(opts, :size)) do
      state = %__MODULE__{
        size: size,
        alternate_screen: Keyword.get(opts, :alternate_screen, true),
        mouse_mode: Keyword.get(opts, :mouse_tracking, :none),
        bracketed_paste: Keyword.get(opts, :bracketed_paste, true),
        focus_events: Keyword.get(opts, :focus_events, true)
      }

      case TerminalOutput.write(setup_sequence(state, Keyword.get(opts, :hide_cursor, true))) do
        :ok -> {:ok, state}
        {:error, reason} -> {:error, {:terminal_write_failed, reason}}
      end
    end
  end

  @impl true
  @spec shutdown(t(), term()) :: :ok
  def shutdown(state, _reason) do
    EventStream.stop(state)
    TerminalOutput.write_to_tty(TerminalOutput.cleanup_sequence())
    safe_write(@all_mouse_off)
    if state.bracketed_paste, do: safe_write(ANSI.disable_bracketed_paste())
    if state.focus_events, do: safe_write(ANSI.disable_focus_events())
    safe_write(ANSI.cursor_show())
    safe_write(ANSI.reset())
    if state.alternate_screen, do: safe_write(ANSI.leave_alternate_screen())
    drain_pending_input()
    safe_cooked_mode()
    :ok
  end

  @impl true
  @spec size(t()) :: {:ok, TermUI.Backend.size()}
  def size(state), do: {:ok, state.size}

  @impl true
  @spec capabilities(t()) :: map()
  def capabilities(state) do
    %{colors: :true_color, unicode: true, mouse: true, size: state.size}
  end

  @spec refresh_size(t()) :: {:ok, TermUI.Backend.size(), t()} | {:error, term()}
  def refresh_size(state) do
    case SizeDetector.detect() do
      {:ok, size} -> {:ok, size, %{state | size: size}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  @spec draw(t(), Frame.t()) :: {:ok, t()} | {:error, term()}
  def draw(state, %Frame{} = frame) do
    reset? = dimensions_changed?(state.last_frame, frame)
    changes = if reset?, do: Frame.cells(frame), else: Frame.diff(state.last_frame, frame)

    output = [
      ANSI.cursor_hide(),
      if(reset?, do: [ANSI.clear_screen(), ANSI.cursor_position(1, 1)], else: []),
      Renderer.render(changes, :true_color, :unicode),
      cursor_sequence(frame.cursor)
    ]

    case TerminalOutput.write(output) do
      :ok -> {:ok, %{state | last_frame: frame}}
      {:error, reason} -> {:error, {:terminal_write_failed, reason}}
    end
  end

  @impl true
  @spec flush(t()) :: {:ok, t()}
  def flush(state), do: {:ok, state}

  @impl true
  @spec clipboard(t(), Clipboard.Operation.t()) :: {:ok, t()} | {:error, term()}
  def clipboard(state, %Clipboard.Operation{} = operation) do
    with {:ok, sequence} <- Clipboard.sequence(operation),
         :ok <- TerminalOutput.write(sequence) do
      {:ok, state}
    else
      {:error, {:clipboard_too_large, _size, _maximum} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:terminal_write_failed, reason}}
    end
  end

  @impl true
  @spec poll_event(t(), non_neg_integer()) ::
          {:ok, TermUI.Backend.event(), t()}
          | {:timeout, t()}
          | {:error, term(), t()}
  def poll_event(state, timeout) do
    EventStream.poll(state, timeout, &read_one_byte/0, __MODULE__)
  end

  @impl true
  @spec resize(t(), TermUI.Backend.size()) :: {:ok, t()} | {:error, term()}
  def resize(state, {rows, columns} = size)
      when is_integer(rows) and rows > 0 and is_integer(columns) and columns > 0 do
    case TerminalOutput.write([ANSI.clear_screen(), ANSI.cursor_position(1, 1)]) do
      :ok -> {:ok, %{state | size: size, last_frame: nil}}
      {:error, reason} -> {:error, {:terminal_write_failed, reason}}
    end
  end

  defp setup_sequence(state, hide_cursor?) do
    mouse =
      if state.mouse_mode != :none and not TerminalOutput.needs_hard_reset?() do
        mode = mouse_mode_to_ansi(state.mouse_mode)
        [ANSI.enable_mouse_tracking(mode), ANSI.enable_sgr_mouse()]
      else
        []
      end

    [
      if(state.alternate_screen, do: ANSI.enter_alternate_screen(), else: []),
      if(hide_cursor?, do: ANSI.cursor_hide(), else: []),
      mouse,
      if(state.bracketed_paste, do: ANSI.enable_bracketed_paste(), else: []),
      if(state.focus_events, do: ANSI.enable_focus_events(), else: []),
      ANSI.clear_screen(),
      ANSI.cursor_position(1, 1)
    ]
  end

  defp cursor_sequence(nil), do: ANSI.cursor_hide()
  defp cursor_sequence({column, row}), do: [ANSI.cursor_position(row, column), ANSI.cursor_show()]

  defp dimensions_changed?(nil, _frame), do: false

  defp dimensions_changed?(previous, current) do
    previous.width != current.width or previous.height != current.height
  end

  defp mouse_mode_to_ansi(:click), do: :normal
  defp mouse_mode_to_ansi(:drag), do: :button
  defp mouse_mode_to_ansi(:all), do: :all

  defp read_one_byte do
    case IO.getn("", 1) do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      data when is_binary(data) -> {:ok, data}
      [byte] when is_integer(byte) -> {:ok, <<byte>>}
      other -> {:error, {:unexpected_io_return, other}}
    end
  end

  defp safe_write(data) do
    _result = TerminalOutput.write(data)
    :ok
  end

  defp safe_cooked_mode do
    _result = :shell.start_interactive({:noshell, :cooked})
    :ok
  rescue
    _exception -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp drain_pending_input do
    case TermUtils.safe_stty(["min", "0", "time", "1"]) do
      {:ok, _output} ->
        try do
          drain_input_loop(0, 20)
        after
          _result = TermUtils.safe_stty(["min", "1", "time", "0"])
        end

      {:error, _reason} ->
        :ok
    end
  rescue
    _exception -> :ok
  end

  defp drain_input_loop(iteration, max) when iteration >= max, do: :ok

  defp drain_input_loop(iteration, max) do
    case IO.read(:stdio, 64) do
      data when is_binary(data) and byte_size(data) > 0 ->
        drain_input_loop(iteration + 1, max)

      _other ->
        :ok
    end
  rescue
    _exception -> :ok
  end
end
