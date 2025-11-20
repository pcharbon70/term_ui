defmodule TermUI.Parser do
  @moduledoc """
  Escape sequence parser for terminal input.

  Transforms raw terminal input bytes into structured events (key presses,
  mouse actions, paste content, focus changes).
  """

  import Bitwise

  alias TermUI.Parser.Events.{FocusEvent, KeyEvent, MouseEvent, PasteEvent}

  @type event :: KeyEvent.t() | MouseEvent.t() | PasteEvent.t() | FocusEvent.t()

  # Map control characters to key events
  @control_chars %{
    0x00 => {" ", [:ctrl]},
    0x01 => {"a", [:ctrl]},
    0x02 => {"b", [:ctrl]},
    0x03 => {"c", [:ctrl]},
    0x04 => {"d", [:ctrl]},
    0x05 => {"e", [:ctrl]},
    0x06 => {"f", [:ctrl]},
    0x07 => {"g", [:ctrl]},
    0x08 => {:backspace, []},
    0x09 => {:tab, []},
    0x0A => {:enter, []},
    0x0B => {"k", [:ctrl]},
    0x0C => {"l", [:ctrl]},
    0x0D => {:enter, []},
    0x0E => {"n", [:ctrl]},
    0x0F => {"o", [:ctrl]},
    0x10 => {"p", [:ctrl]},
    0x11 => {"q", [:ctrl]},
    0x12 => {"r", [:ctrl]},
    0x13 => {"s", [:ctrl]},
    0x14 => {"t", [:ctrl]},
    0x15 => {"u", [:ctrl]},
    0x16 => {"v", [:ctrl]},
    0x17 => {"w", [:ctrl]},
    0x18 => {"x", [:ctrl]},
    0x19 => {"y", [:ctrl]},
    0x1A => {"z", [:ctrl]}
  }

  # Map CSI tilde codes to keys
  @csi_tilde_keys %{
    1 => :home,
    2 => :insert,
    3 => :delete,
    4 => :end,
    5 => :page_up,
    6 => :page_down,
    15 => :f5,
    17 => :f6,
    18 => :f7,
    19 => :f8,
    20 => :f9,
    21 => :f10,
    23 => :f11,
    24 => :f12,
    200 => :paste_start,
    201 => :paste_end
  }

  # Map CSI letter codes to keys
  @csi_letter_keys %{
    ?A => :up,
    ?B => :down,
    ?C => :right,
    ?D => :left,
    ?H => :home,
    ?F => :end,
    ?I => :focus_in,
    ?O => :focus_out
  }

  # Map SS3 codes to keys
  @ss3_keys %{
    ?A => :up,
    ?B => :down,
    ?C => :right,
    ?D => :left,
    ?H => :home,
    ?F => :end,
    ?P => :f1,
    ?Q => :f2,
    ?R => :f3,
    ?S => :f4
  }

  @type state :: %{
          mode: atom(),
          buffer: binary(),
          params: [integer()],
          paste_buffer: binary()
        }

  @doc """
  Creates a new parser state.
  """
  @spec new() :: state()
  def new do
    %{
      mode: :ground,
      buffer: <<>>,
      params: [],
      paste_buffer: <<>>
    }
  end

  @doc """
  Parses input bytes into events.

  Returns `{events, remaining_bytes, new_state}` where:
  - `events` - List of parsed events
  - `remaining_bytes` - Bytes that couldn't be parsed yet (incomplete sequences)
  - `new_state` - Parser state for next call

  ## Examples

      iex> {events, "", _state} = TermUI.Parser.parse("a", TermUI.Parser.new())
      iex> [%TermUI.Parser.Events.KeyEvent{key: "a"}] = events
  """
  @spec parse(binary(), state()) :: {[event()], binary(), state()}
  def parse(input, state) do
    parse_bytes(input, state, [])
  end

  @doc """
  Resets parser state while preserving configuration.
  """
  @spec reset(state()) :: state()
  def reset(_state) do
    new()
  end

  @doc """
  Flushes any pending escape sequence as an ESC key event.

  Call this after a timeout when parser is in :escape state.
  """
  @spec flush_escape(state()) :: {[event()], state()}
  def flush_escape(%{mode: :escape} = state) do
    event = %KeyEvent{key: :escape, modifiers: []}
    {[event], %{state | mode: :ground, buffer: <<>>}}
  end

  def flush_escape(state), do: {[], state}

  # Main parsing loop
  defp parse_bytes(<<>>, state, events) do
    {Enum.reverse(events), <<>>, state}
  end

  defp parse_bytes(input, %{mode: :ground} = state, events) do
    <<byte, rest::binary>> = input

    case byte do
      0x1B ->
        parse_bytes(rest, %{state | mode: :escape, buffer: <<0x1B>>}, events)

      b when b in 0x00..0x1F ->
        event = parse_control_char(b)
        parse_bytes(rest, state, [event | events])

      b when b in 0x20..0x7E ->
        event = %KeyEvent{key: <<b>>, modifiers: []}
        parse_bytes(rest, state, [event | events])

      0x7F ->
        event = %KeyEvent{key: :backspace, modifiers: []}
        parse_bytes(rest, state, [event | events])

      _ ->
        parse_utf8(input, state, events)
    end
  end

  defp parse_bytes(input, %{mode: :escape} = state, events) do
    case input do
      <<>> ->
        {Enum.reverse(events), state.buffer, state}

      <<"[", rest::binary>> ->
        parse_bytes(rest, %{state | mode: :csi, buffer: <<>>, params: []}, events)

      <<"O", rest::binary>> ->
        parse_bytes(rest, %{state | mode: :ss3, buffer: <<>>}, events)

      <<b, rest::binary>> when b in ?a..?z or b in ?A..?Z ->
        event = %KeyEvent{key: <<b>>, modifiers: [:alt]}
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>}, [event | events])

      <<_b, _rest::binary>> ->
        event = %KeyEvent{key: :escape, modifiers: []}
        parse_bytes(input, %{state | mode: :ground, buffer: <<>>}, [event | events])
    end
  end

  defp parse_bytes(input, %{mode: :csi} = state, events) do
    case input do
      <<>> ->
        {Enum.reverse(events), <<0x1B, ?[, state.buffer::binary>>, state}

      <<"<", rest::binary>> ->
        parse_bytes(rest, %{state | mode: :sgr_mouse, buffer: <<>>, params: []}, events)

      <<"M", rest::binary>> when state.buffer == <<>> and state.params == [] ->
        parse_x10_mouse(rest, state, events)

      <<b, rest::binary>> when b in ?0..?9 ->
        parse_bytes(rest, %{state | buffer: <<state.buffer::binary, b>>}, events)

      <<";", rest::binary>> ->
        param = parse_param(state.buffer)
        parse_bytes(rest, %{state | buffer: <<>>, params: state.params ++ [param]}, events)

      <<b, rest::binary>> ->
        parse_csi_terminator(b, rest, state, events)
    end
  end

  defp parse_bytes(input, %{mode: :ss3} = state, events) do
    case input do
      <<>> ->
        {Enum.reverse(events), <<0x1B, ?O>>, state}

      <<b, rest::binary>> when b in ?A..?Z or b in ?a..?z ->
        event = handle_ss3_key(b)
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>}, [event | events])

      <<_b, rest::binary>> ->
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>}, events)
    end
  end

  defp parse_bytes(input, %{mode: :sgr_mouse} = state, events) do
    case input do
      <<>> ->
        {Enum.reverse(events), <<0x1B, ?[, ?<, state.buffer::binary>>, state}

      <<b, rest::binary>> when b in ?0..?9 ->
        parse_bytes(rest, %{state | buffer: <<state.buffer::binary, b>>}, events)

      <<";", rest::binary>> ->
        param = parse_param(state.buffer)
        parse_bytes(rest, %{state | buffer: <<>>, params: state.params ++ [param]}, events)

      <<term, rest::binary>> when term in [?M, ?m] ->
        param = parse_param(state.buffer)
        params = state.params ++ [param]
        event = parse_sgr_mouse_event(params, term)
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>, params: []}, [event | events])

      <<_b, rest::binary>> ->
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>, params: []}, events)
    end
  end

  defp parse_bytes(input, %{mode: :paste} = state, events) do
    case :binary.match(input, <<0x1B, ?[, ?2, ?0, ?1, ?~>>) do
      {pos, 6} ->
        content = binary_part(input, 0, pos)
        rest = binary_part(input, pos + 6, byte_size(input) - pos - 6)
        full_content = <<state.paste_buffer::binary, content::binary>>
        event = %PasteEvent{content: full_content}

        parse_bytes(rest, %{state | mode: :ground, paste_buffer: <<>>}, [event | events])

      :nomatch ->
        {Enum.reverse(events), <<>>, %{state | paste_buffer: <<state.paste_buffer::binary, input::binary>>}}
    end
  end

  defp parse_bytes(input, state, events) do
    <<_byte, rest::binary>> = input
    parse_bytes(rest, %{state | mode: :ground}, events)
  end

  # Handle CSI terminator characters
  defp parse_csi_terminator(?~, rest, state, events) do
    {event, new_state} = handle_csi_tilde(state)

    events =
      if event == nil do
        events
      else
        [event | events]
      end

    parse_bytes(rest, new_state, events)
  end

  defp parse_csi_terminator(b, rest, state, events) when b in ?A..?Z do
    {event, new_state} = handle_csi_letter(b, state)
    parse_bytes(rest, new_state, [event | events])
  end

  defp parse_csi_terminator(_b, rest, state, events) do
    parse_bytes(rest, %{state | mode: :ground, buffer: <<>>, params: []}, events)
  end

  # Parse UTF-8 characters
  defp parse_utf8(input, state, events) do
    case input do
      <<c::utf8, rest::binary>> ->
        event = %KeyEvent{key: <<c::utf8>>, modifiers: []}
        parse_bytes(rest, state, [event | events])

      _ ->
        <<_byte, rest::binary>> = input
        parse_bytes(rest, state, events)
    end
  end

  # Parse control characters (Ctrl+key)
  defp parse_control_char(byte) do
    case Map.get(@control_chars, byte) do
      {key, modifiers} -> %KeyEvent{key: key, modifiers: modifiers}
      nil -> %KeyEvent{key: :unknown, modifiers: []}
    end
  end

  # Handle CSI sequences ending with ~
  defp handle_csi_tilde(state) do
    param = parse_param(state.buffer)
    params = state.params ++ [param]
    key = Map.get(@csi_tilde_keys, hd(params), :unknown)
    modifiers = extract_modifiers(params)

    case key do
      :paste_start ->
        {nil, %{state | mode: :paste, buffer: <<>>, params: [], paste_buffer: <<>>}}

      :paste_end ->
        {nil, %{state | mode: :ground, buffer: <<>>, params: []}}

      _ ->
        event = %KeyEvent{key: key, modifiers: modifiers}
        {event, %{state | mode: :ground, buffer: <<>>, params: []}}
    end
  end

  # Handle CSI sequences ending with a letter
  defp handle_csi_letter(letter, state) do
    param = if state.buffer == <<>>, do: 0, else: parse_param(state.buffer)
    params = if param == 0 and state.params == [], do: [], else: state.params ++ [param]
    key = Map.get(@csi_letter_keys, letter, :unknown)
    modifiers = extract_modifiers(params)

    case key do
      :focus_in ->
        event = %FocusEvent{focused: true}
        {event, %{state | mode: :ground, buffer: <<>>, params: []}}

      :focus_out ->
        event = %FocusEvent{focused: false}
        {event, %{state | mode: :ground, buffer: <<>>, params: []}}

      _ ->
        event = %KeyEvent{key: key, modifiers: modifiers}
        {event, %{state | mode: :ground, buffer: <<>>, params: []}}
    end
  end

  # Handle SS3 key sequences (F1-F4, arrow keys in application mode)
  defp handle_ss3_key(byte) do
    key = Map.get(@ss3_keys, byte, :unknown)
    %KeyEvent{key: key, modifiers: []}
  end

  # Parse X10 mouse event
  defp parse_x10_mouse(input, state, events) do
    case input do
      <<button, col, row, rest::binary>> ->
        event = parse_x10_mouse_event(button - 32, col - 32, row - 32)
        parse_bytes(rest, %{state | mode: :ground, buffer: <<>>, params: []}, [event | events])

      _ ->
        {Enum.reverse(events), <<0x1B, ?[, ?M, input::binary>>, state}
    end
  end

  defp parse_x10_mouse_event(button_byte, col, row) do
    {button, action} = decode_x10_button(button_byte)
    modifiers = decode_mouse_modifiers(button_byte)

    %MouseEvent{
      action: action,
      button: button,
      x: max(1, col),
      y: max(1, row),
      modifiers: modifiers
    }
  end

  defp decode_x10_button(byte) do
    base = byte &&& 0x03
    motion = (byte &&& 0x20) != 0
    wheel = (byte &&& 0x40) != 0

    cond do
      wheel and base == 0 -> {:wheel_up, :press}
      wheel and base == 1 -> {:wheel_down, :press}
      motion -> {decode_button_base(base), :motion}
      base == 3 -> {:none, :release}
      true -> {decode_button_base(base), :press}
    end
  end

  defp decode_button_base(base) do
    case base do
      0 -> :left
      1 -> :middle
      2 -> :right
      _ -> :none
    end
  end

  # Parse SGR mouse event
  defp parse_sgr_mouse_event(params, terminator) do
    [button_byte, col, row] =
      case params do
        [b, c, r] -> [b, c, r]
        _ -> [0, 1, 1]
      end

    action = if terminator == ?M, do: :press, else: :release
    {button, action} = decode_sgr_button(button_byte, action)
    modifiers = decode_mouse_modifiers(button_byte)

    %MouseEvent{
      action: action,
      button: button,
      x: max(1, col),
      y: max(1, row),
      modifiers: modifiers
    }
  end

  defp decode_sgr_button(byte, default_action) do
    base = byte &&& 0x03
    motion = (byte &&& 0x20) != 0
    wheel = (byte &&& 0x40) != 0

    cond do
      wheel and base == 0 -> {:wheel_up, :press}
      wheel and base == 1 -> {:wheel_down, :press}
      motion -> {decode_button_base(base), :motion}
      true -> {decode_button_base(base), default_action}
    end
  end

  defp decode_mouse_modifiers(byte) do
    modifiers = []
    modifiers = if (byte &&& 0x04) != 0, do: [:shift | modifiers], else: modifiers
    modifiers = if (byte &&& 0x08) != 0, do: [:alt | modifiers], else: modifiers
    modifiers = if (byte &&& 0x10) != 0, do: [:ctrl | modifiers], else: modifiers
    modifiers
  end

  # Extract keyboard modifiers from CSI parameters
  defp extract_modifiers(params) do
    modifier_param =
      case params do
        [_, m | _] -> m
        _ -> 1
      end

    modifiers = []
    modifier_value = modifier_param - 1
    modifiers = if (modifier_value &&& 1) != 0, do: [:shift | modifiers], else: modifiers
    modifiers = if (modifier_value &&& 2) != 0, do: [:alt | modifiers], else: modifiers
    modifiers = if (modifier_value &&& 4) != 0, do: [:ctrl | modifiers], else: modifiers
    modifiers = if (modifier_value &&& 8) != 0, do: [:meta | modifiers], else: modifiers
    modifiers
  end

  defp parse_param(<<>>), do: 0

  defp parse_param(buffer) do
    case Integer.parse(buffer) do
      {n, ""} -> n
      _ -> 0
    end
  end
end
