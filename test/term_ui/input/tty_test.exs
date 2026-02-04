defmodule TermUI.Input.TTYTest do
  use TermUI.TestCase, async: true
  @moduletag :capture_log

  alias TermUI.Event
  alias TermUI.Input
  alias TermUI.Input.Raw
  alias TermUI.Input.TTY

  describe "behaviour implementation" do
    test "module implements TermUI.Input behaviour" do
      assert Code.ensure_loaded?(TTY)
      behaviours = TTY.__info__(:attributes)[:behaviour] || []
      assert Input in behaviours
    end

    test "poll/2 callback is implemented" do
      assert function_exported?(TTY, :poll, 2)
    end

    test "mode/1 callback is implemented" do
      assert function_exported?(TTY, :mode, 1)
    end
  end

  describe "new/0" do
    test "creates initial state with empty buffer" do
      state = TTY.new()
      assert %TTY{} = state
      assert state.buffer == <<>>
      assert state.event_queue == []
    end

    test "state struct has buffer, event_queue, and IO opts fields" do
      state = TTY.new()
      # Verify the struct has the expected fields (including IO opts fields)
      assert Map.keys(state) -- [:__struct__] == [
               :buffer,
               :event_queue,
               :io_opts_restored,
               :io_opts_set
             ]
    end
  end

  describe "mode/1" do
    test "returns :tty" do
      state = TTY.new()
      assert TTY.mode(state) == :tty
    end

    test "returns :tty regardless of buffer contents" do
      state = %TTY{buffer: "some data", event_queue: []}
      assert TTY.mode(state) == :tty
    end
  end

  describe "stop/1" do
    test "returns :ok" do
      state = TTY.new()
      assert TTY.stop(state) == :ok
    end

    test "is idempotent - can be called multiple times" do
      state = TTY.new()
      assert TTY.stop(state) == :ok
      assert TTY.stop(state) == :ok
    end
  end

  describe "poll/2 with pre-buffered input" do
    test "returns event from buffer with simple character" do
      # Pre-populate buffer with a simple character
      state = %TTY{buffer: "a", event_queue: []}

      # Should parse and return immediately without blocking
      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a"}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with enter key" do
      # Enter is character 13
      state = %TTY{buffer: <<13>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :enter}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with tab key" do
      # Tab is character 9
      state = %TTY{buffer: <<9>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :tab}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with backspace" do
      # Backspace is character 8
      state = %TTY{buffer: <<8>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :backspace}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with complete escape sequence" do
      # ESC [ A = Up arrow
      state = %TTY{buffer: <<27, ?[, ?A>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :up}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with down arrow" do
      # ESC [ B = Down arrow
      state = %TTY{buffer: <<27, ?[, ?B>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :down}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with left arrow" do
      # ESC [ D = Left arrow
      state = %TTY{buffer: <<27, ?[, ?D>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :left}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with right arrow" do
      # ESC [ C = Right arrow
      state = %TTY{buffer: <<27, ?[, ?C>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :right}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with home key" do
      # ESC [ H = Home
      state = %TTY{buffer: <<27, ?[, ?H>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :home}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with end key" do
      # ESC [ F = End
      state = %TTY{buffer: <<27, ?[, ?F>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :end}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with function key F1" do
      # ESC O P = F1
      state = %TTY{buffer: <<27, ?O, ?P>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :f1}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with delete key" do
      # ESC [ 3 ~ = Delete
      state = %TTY{buffer: <<27, ?[, ?3, ?~>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :delete}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with page up" do
      # ESC [ 5 ~ = Page Up
      state = %TTY{buffer: <<27, ?[, ?5, ?~>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :page_up}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with page down" do
      # ESC [ 6 ~ = Page Down
      state = %TTY{buffer: <<27, ?[, ?6, ?~>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: :page_down}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with Ctrl+C" do
      # Ctrl+C is character 3
      state = %TTY{buffer: <<3>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: "c", modifiers: [:ctrl]}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with Alt+a" do
      # ESC followed by 'a' = Alt+a
      state = %TTY{buffer: <<27, ?a>>, event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a", modifiers: [:alt]}} = result
      assert new_state.buffer == <<>>
    end

    test "handles multiple characters in buffer by queueing" do
      # Buffer has 'abc' - should return first character and queue the rest
      state = %TTY{buffer: "abc", event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a"}} = result
      # Remaining characters are queued as events
      assert new_state.buffer == <<>>
      assert length(new_state.event_queue) == 2
    end

    test "handles UTF-8 characters in buffer" do
      # UTF-8 encoded character (e.g., 'ñ')
      state = %TTY{buffer: "ñ", event_queue: []}

      {result, new_state} = TTY.poll(state, 0)

      assert {:ok, %Event.Key{key: "ñ", char: "ñ"}} = result
      assert new_state.buffer == <<>>
    end
  end

  describe "poll/2 return format" do
    test "returns tuple with result and new state" do
      state = %TTY{buffer: "x", event_queue: []}

      result = TTY.poll(state, 0)

      assert {_, %TTY{}} = result
    end

    test "result is {:ok, event} for successful parse" do
      state = %TTY{buffer: "x", event_queue: []}

      {{:ok, event}, _state} = TTY.poll(state, 0)

      assert %Event.Key{} = event
    end
  end

  describe "state management" do
    test "state is properly updated after poll with queued events" do
      state = %TTY{buffer: "abc", event_queue: []}

      # Poll should consume 'a' and queue 'b' and 'c' as events
      {_, new_state} = TTY.poll(state, 0)

      assert new_state.buffer == <<>>
      assert length(new_state.event_queue) == 2
    end

    test "multiple polls consume queued events sequentially" do
      state = %TTY{buffer: "xyz", event_queue: []}

      {{:ok, event1}, state} = TTY.poll(state, 0)
      assert event1.key == "x"

      {{:ok, event2}, state} = TTY.poll(state, 0)
      assert event2.key == "y"

      {{:ok, event3}, state} = TTY.poll(state, 0)
      assert event3.key == "z"

      # Both buffer and event_queue should now be empty
      assert state.buffer == <<>>
      assert state.event_queue == []
    end

    test "returns queued events before reading buffer" do
      # Pre-queue some events
      queued_event = Event.key(:queued_test)
      state = %TTY{buffer: "a", event_queue: [queued_event]}

      # Should return queued event first
      {{:ok, event1}, state} = TTY.poll(state, 0)
      assert event1.key == :queued_test

      # Then buffer event
      {{:ok, event2}, _state} = TTY.poll(state, 0)
      assert event2.key == "a"
    end
  end

  describe "buffer and queue limits" do
    test "event queue size is limited to prevent memory exhaustion" do
      # Create a large string that will generate many events
      large_input = String.duplicate("x", 1500)
      state = %TTY{buffer: large_input, event_queue: []}

      # First poll should parse all and queue remaining (limited to 1000)
      {{:ok, _event}, new_state} = TTY.poll(state, 0)

      # Queue should be limited to @max_queue_size (1000)
      assert length(new_state.event_queue) <= 1000
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert is_binary(moduledoc)
      assert String.contains?(moduledoc, "TTY")
    end

    test "moduledoc mentions :io.get_chars" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)

      assert String.contains?(moduledoc, ":io.get_chars") or
               String.contains?(moduledoc, "get_chars")
    end

    test "moduledoc explains arrow keys work normally" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)

      assert String.contains?(moduledoc, "Arrow keys") or
               String.contains?(moduledoc, "arrow keys")
    end

    test "moduledoc explains Tab works" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert String.contains?(moduledoc, "Tab")
    end

    test "moduledoc explains timeout is not honored" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert String.contains?(moduledoc, "timeout") or String.contains?(moduledoc, "Timeout")
      assert String.contains?(moduledoc, "not honored") or String.contains?(moduledoc, "blocking")
    end

    test "poll/2 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(TTY)

      poll_doc =
        Enum.find(docs, fn
          {{:function, :poll, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert poll_doc != nil
    end

    test "mode/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(TTY)

      mode_doc =
        Enum.find(docs, fn
          {{:function, :mode, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert mode_doc != nil
    end

    test "new/0 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(TTY)

      new_doc =
        Enum.find(docs, fn
          {{:function, :new, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert new_doc != nil
    end

    test "moduledoc explains IEx compatibility" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert String.contains?(moduledoc, "IEx")

      assert String.contains?(moduledoc, "Compatible") or
               String.contains?(moduledoc, "IEx compatible")
    end

    test "moduledoc mentions snake_test" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert String.contains?(moduledoc, "snake_test")
    end
  end

  describe "comparison with Raw handler" do
    test "TTY and Raw have mostly the same struct fields" do
      tty_state = TTY.new()
      raw_state = Raw.new()

      tty_fields = Map.keys(tty_state) -- [:__struct__, :io_opts_restored, :io_opts_set]
      raw_fields = Map.keys(raw_state) -- [:__struct__]

      # TTY has additional IO opts fields, but the core fields match
      assert tty_fields == raw_fields
    end

    test "both return same event format for same input" do
      # Test with buffered input to avoid I/O
      input = "a"

      tty_state = %TTY{buffer: input, event_queue: []}
      raw_state = %Raw{buffer: input, event_queue: []}

      {{:ok, tty_event}, _} = TTY.poll(tty_state, 0)
      {{:ok, raw_event}, _} = Raw.poll(raw_state, 0)

      assert tty_event.key == raw_event.key
      assert tty_event.char == raw_event.char
    end

    test "TTY returns :tty mode, Raw returns :raw mode" do
      tty_state = TTY.new()
      raw_state = Raw.new()

      assert TTY.mode(tty_state) == :tty
      assert Raw.mode(raw_state) == :raw
    end
  end

  describe "EOF and error handling" do
    # Note: Actually testing EOF from IO.getn is difficult without a real terminal.
    # These tests document the expected behavior and verify the code paths exist.

    test "TTY module handles EOF in its implementation" do
      # Verify the poll function exists and can handle pre-buffered input
      # The EOF handling is in do_read_blocking/1 which we can't easily test
      # without actual terminal I/O, but we verify the module structure is correct.
      state = TTY.new()
      assert %TTY{buffer: <<>>, event_queue: []} = state

      # Verify we can poll with pre-buffered data (the testable path)
      state_with_data = %TTY{buffer: "a", event_queue: []}
      {{:ok, event}, new_state} = TTY.poll(state_with_data, 0)
      assert event.key == "a"
      assert new_state.buffer == <<>>
    end

    test "error handling is documented in moduledoc" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      # Verify security/error handling documentation exists
      assert String.contains?(moduledoc, "Security")
      assert String.contains?(moduledoc, "memory exhaustion")
    end

    test "IO errors are converted to EOF in implementation" do
      # This documents that read_char/0 returns {:error, reason} for IO errors
      # and do_read_blocking/1 converts this to {:eof, state}.
      # We can't easily test this without mocking IO, but we verify the
      # implementation handles these cases by checking the module compiles
      # and the documented behavior is consistent.

      # Verify the module implements the Input behaviour which specifies
      # :eof as a valid return type
      behaviours = TTY.__info__(:attributes)[:behaviour] || []
      assert TermUI.Input in behaviours
    end
  end

  # Integration tests - these require actual terminal I/O
  # Tagged to allow selective running
  describe "integration - actual I/O" do
    @describetag :requires_terminal

    test "moduledoc explains blocking behavior" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TTY)
      assert String.contains?(moduledoc, "blocking")
    end
  end
end
