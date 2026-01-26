defmodule TermUI.Terminal.EscapeParser do
  @moduledoc """
  Parses terminal escape sequences into Event structs.

  Handles CSI sequences (ESC[...), SS3 sequences (ESCO...), and control
  characters. Returns parsed events and any remaining unparsed bytes.

  ## Supported Sequences

  - Arrow keys: ESC[A/B/C/D
  - Function keys: F1-F12 (both SS3 and CSI variants)
  - Home/End/Insert/Delete/PageUp/PageDown
  - Ctrl+key: 0x01-0x1A
  - Alt+key: ESC followed by key
  - Regular printable characters
  """

  import Bitwise

  alias TermUI.Event

  @escape 0x1B
  @delete 0x7F

  # Maximum coordinate value for mouse events.
  # Provides defense against malicious input with huge coordinates.
  @max_mouse_coordinate 9999

  @doc """
  Parses input bytes into a list of events and remaining bytes.

  Returns `{events, remaining}` where events is a list of Event.Key structs
  and remaining is bytes that couldn't be parsed yet (partial sequences).
  """
  @spec parse(binary()) :: {[Event.Key.t()], binary()}
  def parse(<<>>), do: {[], <<>>}

  def parse(input) when is_binary(input) do
    parse_bytes(input, [])
  end

  defp parse_bytes(<<>>, events), do: {Enum.reverse(events), <<>>}

  # Escape sequence start
  defp parse_bytes(<<@escape, rest::binary>>, events) do
    case parse_escape_sequence(rest) do
      {:ok, event, remaining} ->
        parse_bytes(remaining, [event | events])

      :incomplete ->
        # Return ESC + rest as remaining for buffering
        {Enum.reverse(events), <<@escape, rest::binary>>}
    end
  end

  # Backspace / Ctrl+H
  defp parse_bytes(<<8, rest::binary>>, events) do
    event = Event.key(:backspace)
    parse_bytes(rest, [event | events])
  end

  # Tab / Ctrl+I
  defp parse_bytes(<<9, rest::binary>>, events) do
    event = Event.key(:tab)
    parse_bytes(rest, [event | events])
  end

  # Enter / Ctrl+M
  defp parse_bytes(<<13, rest::binary>>, events) do
    event = Event.key(:enter)
    parse_bytes(rest, [event | events])
  end

  # Control characters (Ctrl+A through Ctrl+Z, except backspace/tab/enter)
  defp parse_bytes(<<char, rest::binary>>, events) when char in 1..26 do
    # Convert to lowercase letter
    key = <<char + 96>>
    event = Event.key(key, modifiers: [:ctrl])
    parse_bytes(rest, [event | events])
  end

  # Delete key
  defp parse_bytes(<<@delete, rest::binary>>, events) do
    event = Event.key(:backspace)
    parse_bytes(rest, [event | events])
  end

  # Regular printable ASCII
  defp parse_bytes(<<char, rest::binary>>, events) when char in 32..126 do
    char_str = <<char>>
    event = Event.key(char_str, char: char_str)
    parse_bytes(rest, [event | events])
  end

  # UTF-8 multi-byte sequences (2-byte)
  defp parse_bytes(<<0b110::3, _::5, 0b10::2, _::6, _rest::binary>> = input, events) do
    case input do
      <<char::utf8, rest::binary>> ->
        char_str = <<char::utf8>>
        event = Event.key(char_str, char: char_str)
        parse_bytes(rest, [event | events])

      _ ->
        # Incomplete UTF-8
        {Enum.reverse(events), input}
    end
  end

  # UTF-8 multi-byte sequences (3-byte)
  defp parse_bytes(<<0b1110::4, _::4, _rest::binary>> = input, events) do
    case input do
      <<char::utf8, rest::binary>> ->
        char_str = <<char::utf8>>
        event = Event.key(char_str, char: char_str)
        parse_bytes(rest, [event | events])

      _ ->
        {Enum.reverse(events), input}
    end
  end

  # UTF-8 multi-byte sequences (4-byte)
  defp parse_bytes(<<0b11110::5, _::3, _rest::binary>> = input, events) do
    case input do
      <<char::utf8, rest::binary>> ->
        char_str = <<char::utf8>>
        event = Event.key(char_str, char: char_str)
        parse_bytes(rest, [event | events])

      _ ->
        {Enum.reverse(events), input}
    end
  end

  # Unknown byte - skip it
  defp parse_bytes(<<_char, rest::binary>>, events) do
    parse_bytes(rest, events)
  end

  # Parse escape sequences
  defp parse_escape_sequence(<<>>) do
    :incomplete
  end

  # CSI sequences (ESC [)
  defp parse_escape_sequence(<<"[", rest::binary>>) do
    parse_csi_sequence(rest)
  end

  # SS3 sequences (ESC O) - typically function keys
  defp parse_escape_sequence(<<"O", rest::binary>>) do
    parse_ss3_sequence(rest)
  end

  # Alt+key (ESC followed by printable character)
  defp parse_escape_sequence(<<char, rest::binary>>) when char in 32..126 do
    char_str = <<char>>
    event = Event.key(char_str, char: char_str, modifiers: [:alt])
    {:ok, event, rest}
  end

  # Just ESC key (no following sequence) - but need to wait for timeout
  defp parse_escape_sequence(_rest) do
    :incomplete
  end

  # CSI sequence parsing
  defp parse_csi_sequence(<<>>) do
    :incomplete
  end

  # Arrow keys
  defp parse_csi_sequence(<<"A", rest::binary>>), do: {:ok, Event.key(:up), rest}
  defp parse_csi_sequence(<<"B", rest::binary>>), do: {:ok, Event.key(:down), rest}
  defp parse_csi_sequence(<<"C", rest::binary>>), do: {:ok, Event.key(:right), rest}
  defp parse_csi_sequence(<<"D", rest::binary>>), do: {:ok, Event.key(:left), rest}

  # Home/End
  defp parse_csi_sequence(<<"H", rest::binary>>), do: {:ok, Event.key(:home), rest}
  defp parse_csi_sequence(<<"F", rest::binary>>), do: {:ok, Event.key(:end), rest}

  # Tilde sequences: ESC [ number ~
  defp parse_csi_sequence(<<"1~", rest::binary>>), do: {:ok, Event.key(:home), rest}
  defp parse_csi_sequence(<<"2~", rest::binary>>), do: {:ok, Event.key(:insert), rest}
  defp parse_csi_sequence(<<"3~", rest::binary>>), do: {:ok, Event.key(:delete), rest}
  defp parse_csi_sequence(<<"4~", rest::binary>>), do: {:ok, Event.key(:end), rest}
  defp parse_csi_sequence(<<"5~", rest::binary>>), do: {:ok, Event.key(:page_up), rest}
  defp parse_csi_sequence(<<"6~", rest::binary>>), do: {:ok, Event.key(:page_down), rest}

  # Function keys F1-F4 (some terminals)
  defp parse_csi_sequence(<<"11~", rest::binary>>), do: {:ok, Event.key(:f1), rest}
  defp parse_csi_sequence(<<"12~", rest::binary>>), do: {:ok, Event.key(:f2), rest}
  defp parse_csi_sequence(<<"13~", rest::binary>>), do: {:ok, Event.key(:f3), rest}
  defp parse_csi_sequence(<<"14~", rest::binary>>), do: {:ok, Event.key(:f4), rest}

  # Function keys F5-F12
  defp parse_csi_sequence(<<"15~", rest::binary>>), do: {:ok, Event.key(:f5), rest}
  defp parse_csi_sequence(<<"17~", rest::binary>>), do: {:ok, Event.key(:f6), rest}
  defp parse_csi_sequence(<<"18~", rest::binary>>), do: {:ok, Event.key(:f7), rest}
  defp parse_csi_sequence(<<"19~", rest::binary>>), do: {:ok, Event.key(:f8), rest}
  defp parse_csi_sequence(<<"20~", rest::binary>>), do: {:ok, Event.key(:f9), rest}
  defp parse_csi_sequence(<<"21~", rest::binary>>), do: {:ok, Event.key(:f10), rest}
  defp parse_csi_sequence(<<"23~", rest::binary>>), do: {:ok, Event.key(:f11), rest}
  defp parse_csi_sequence(<<"24~", rest::binary>>), do: {:ok, Event.key(:f12), rest}

  # Modified arrow keys with modifiers: ESC [ 1 ; modifier A/B/C/D
  defp parse_csi_sequence(<<"1;", modifier, dir, rest::binary>>)
       when dir in [?A, ?B, ?C, ?D] do
    key =
      case dir do
        ?A -> :up
        ?B -> :down
        ?C -> :right
        ?D -> :left
      end

    modifiers = decode_modifier(modifier - ?0)
    event = Event.key(key, modifiers: modifiers)
    {:ok, event, rest}
  end

  # SGR mouse events: ESC [ < Cb ; Cx ; Cy M/m
  defp parse_csi_sequence(<<"<", rest::binary>>) do
    parse_sgr_mouse(rest)
  end

  # Incomplete CSI sequence - need more bytes
  defp parse_csi_sequence(input) do
    # Check if we have a partial number sequence
    if partial_csi?(input) do
      :incomplete
    else
      # Unknown sequence, skip it
      {:ok, Event.key(:unknown), input}
    end
  end

  # SS3 sequence parsing (ESC O)
  defp parse_ss3_sequence(<<>>) do
    :incomplete
  end

  # Function keys F1-F4
  defp parse_ss3_sequence(<<"P", rest::binary>>), do: {:ok, Event.key(:f1), rest}
  defp parse_ss3_sequence(<<"Q", rest::binary>>), do: {:ok, Event.key(:f2), rest}
  defp parse_ss3_sequence(<<"R", rest::binary>>), do: {:ok, Event.key(:f3), rest}
  defp parse_ss3_sequence(<<"S", rest::binary>>), do: {:ok, Event.key(:f4), rest}

  # Keypad arrows (application mode)
  defp parse_ss3_sequence(<<"A", rest::binary>>), do: {:ok, Event.key(:up), rest}
  defp parse_ss3_sequence(<<"B", rest::binary>>), do: {:ok, Event.key(:down), rest}
  defp parse_ss3_sequence(<<"C", rest::binary>>), do: {:ok, Event.key(:right), rest}
  defp parse_ss3_sequence(<<"D", rest::binary>>), do: {:ok, Event.key(:left), rest}

  # Home/End (keypad)
  defp parse_ss3_sequence(<<"H", rest::binary>>), do: {:ok, Event.key(:home), rest}
  defp parse_ss3_sequence(<<"F", rest::binary>>), do: {:ok, Event.key(:end), rest}

  defp parse_ss3_sequence(_input) do
    :incomplete
  end

  # SGR mouse sequence parsing: Cb;Cx;CyM or Cb;Cx;Cym
  defp parse_sgr_mouse(input) do
    # Find the terminator (M for press, m for release)
    case find_mouse_terminator(input) do
      {:ok, params, terminator, rest} ->
        case parse_mouse_params(params) do
          {:ok, cb, cx, cy} ->
            event = decode_mouse_event(cb, cx, cy, terminator)
            {:ok, event, rest}

          :error ->
            {:ok, Event.key(:unknown), input}
        end

      :incomplete ->
        :incomplete
    end
  end

  defp find_mouse_terminator(input) do
    find_mouse_terminator(input, <<>>)
  end

  defp find_mouse_terminator(<<>>, _acc), do: :incomplete

  defp find_mouse_terminator(<<"M", rest::binary>>, acc) do
    {:ok, acc, :press, rest}
  end

  defp find_mouse_terminator(<<"m", rest::binary>>, acc) do
    {:ok, acc, :release, rest}
  end

  defp find_mouse_terminator(<<char, rest::binary>>, acc) when char in [?0..?9, ?;] do
    find_mouse_terminator(rest, <<acc::binary, char>>)
  end

  defp find_mouse_terminator(<<char, rest::binary>>, acc) when char >= ?0 and char <= ?9 do
    find_mouse_terminator(rest, <<acc::binary, char>>)
  end

  defp find_mouse_terminator(<<";", rest::binary>>, acc) do
    find_mouse_terminator(rest, <<acc::binary, ";">>)
  end

  defp find_mouse_terminator(_input, _acc), do: :incomplete

  defp parse_mouse_params(params) do
    case String.split(params, ";") do
      [cb_str, cx_str, cy_str] ->
        with {cb, ""} <- Integer.parse(cb_str),
             {cx, ""} <- Integer.parse(cx_str),
             {cy, ""} <- Integer.parse(cy_str),
             true <- cb >= 0 and cb <= 255,
             true <- cx >= 0 and cx <= @max_mouse_coordinate,
             true <- cy >= 0 and cy <= @max_mouse_coordinate do
          {:ok, cb, cx, cy}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp decode_mouse_event(cb, cx, cy, terminator) do
    # Extract button from lower bits (0-2)
    button_code = cb &&& 0b11

    # Check for scroll (bit 6) and motion (bit 5)
    is_scroll = (cb &&& 64) != 0
    is_motion = (cb &&& 32) != 0

    # Determine action and button
    {action, button} =
      cond do
        is_scroll and button_code == 0 ->
          {:scroll_up, nil}

        is_scroll and button_code == 1 ->
          {:scroll_down, nil}

        is_motion and terminator == :press ->
          # Motion with button held = drag
          button = decode_button(button_code)
          {:drag, button}

        terminator == :release ->
          # On release, button_code is usually 3 (meaning "released")
          # We use :left as default since we don't track which was pressed
          {:release, :left}

        true ->
          # Normal press
          button = decode_button(button_code)
          {:press, button}
      end

    # Extract modifiers from bits 2-4
    modifiers = []
    modifiers = if (cb &&& 4) != 0, do: [:shift | modifiers], else: modifiers
    modifiers = if (cb &&& 8) != 0, do: [:alt | modifiers], else: modifiers
    modifiers = if (cb &&& 16) != 0, do: [:ctrl | modifiers], else: modifiers

    # Convert 1-indexed terminal coords to 0-indexed
    x = cx - 1
    y = cy - 1

    Event.mouse(action, button, x, y, modifiers: modifiers)
  end

  defp decode_button(0), do: :left
  defp decode_button(1), do: :middle
  defp decode_button(2), do: :right
  defp decode_button(_), do: nil

  # Check if input looks like a partial CSI sequence
  defp partial_csi?(input) do
    # CSI sequences end with a letter or ~
    # If we only have numbers and ; so far, it's partial
    # Also handle SGR mouse sequences that start with <
    String.match?(input, ~r/^[\d;]*$/) or String.match?(input, ~r/^<[\d;]*$/)
  end

  # Decode modifier byte (2=shift, 3=alt, 4=shift+alt, 5=ctrl, etc.)
  # Returns a list of modifiers like [:shift, :alt, :ctrl]
  defp decode_modifier(n) do
    # Modifier is 1-based
    n = n - 1
    modifiers = []
    modifiers = if (n &&& 1) != 0, do: [:shift | modifiers], else: modifiers
    modifiers = if (n &&& 2) != 0, do: [:alt | modifiers], else: modifiers
    modifiers = if (n &&& 4) != 0, do: [:ctrl | modifiers], else: modifiers
    modifiers
  end

  @doc """
  Checks if the given bytes might be a partial escape sequence.

  Used to determine if we should wait for more input or emit a lone ESC.
  """
  @spec partial_sequence?(binary()) :: boolean()
  def partial_sequence?(<<@escape>>), do: true
  def partial_sequence?(<<@escape, "[">>), do: true
  def partial_sequence?(<<@escape, "[", rest::binary>>), do: partial_csi?(rest)
  def partial_sequence?(<<@escape, "O">>), do: true
  def partial_sequence?(_), do: false
end
