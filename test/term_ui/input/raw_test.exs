defmodule TermUI.Input.RawTest do
  use ExUnit.Case, async: true

  alias TermUI.Input.Raw
  alias TermUI.Input
  alias TermUI.Event

  describe "behaviour implementation" do
    test "module implements TermUI.Input behaviour" do
      assert Code.ensure_loaded?(Raw)
      behaviours = Raw.__info__(:attributes)[:behaviour] || []
      assert Input in behaviours
    end

    test "poll/2 callback is implemented" do
      assert function_exported?(Raw, :poll, 2)
    end

    test "mode/1 callback is implemented" do
      assert function_exported?(Raw, :mode, 1)
    end
  end

  describe "new/0" do
    test "creates initial state with empty buffer" do
      state = Raw.new()
      assert %Raw{} = state
      assert state.buffer == <<>>
      assert state.event_queue == []
      assert state.reader_task == nil
    end
  end

  describe "mode/1" do
    test "returns :raw" do
      state = Raw.new()
      assert Raw.mode(state) == :raw
    end

    test "returns :raw regardless of buffer contents" do
      state = %Raw{buffer: "some data", event_queue: [], reader_task: nil}
      assert Raw.mode(state) == :raw
    end
  end

  describe "poll/2 with pre-buffered input" do
    test "returns event from buffer with simple character" do
      # Pre-populate buffer with a simple character
      state = %Raw{buffer: "a", event_queue: [], reader_task: nil}

      # Should parse and return immediately without blocking
      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a"}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with enter key" do
      # Enter is character 13
      state = %Raw{buffer: <<13>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :enter}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with tab key" do
      # Tab is character 9
      state = %Raw{buffer: <<9>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :tab}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with backspace" do
      # Backspace is character 8
      state = %Raw{buffer: <<8>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :backspace}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with complete escape sequence" do
      # ESC [ A = Up arrow
      state = %Raw{buffer: <<27, ?[, ?A>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :up}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with down arrow" do
      # ESC [ B = Down arrow
      state = %Raw{buffer: <<27, ?[, ?B>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :down}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with left arrow" do
      # ESC [ D = Left arrow
      state = %Raw{buffer: <<27, ?[, ?D>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :left}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with right arrow" do
      # ESC [ C = Right arrow
      state = %Raw{buffer: <<27, ?[, ?C>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :right}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with home key" do
      # ESC [ H = Home
      state = %Raw{buffer: <<27, ?[, ?H>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :home}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with end key" do
      # ESC [ F = End
      state = %Raw{buffer: <<27, ?[, ?F>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :end}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with function key F1" do
      # ESC O P = F1
      state = %Raw{buffer: <<27, ?O, ?P>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :f1}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with delete key" do
      # ESC [ 3 ~ = Delete
      state = %Raw{buffer: <<27, ?[, ?3, ?~>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :delete}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with page up" do
      # ESC [ 5 ~ = Page Up
      state = %Raw{buffer: <<27, ?[, ?5, ?~>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :page_up}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with page down" do
      # ESC [ 6 ~ = Page Down
      state = %Raw{buffer: <<27, ?[, ?6, ?~>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: :page_down}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with Ctrl+C" do
      # Ctrl+C is character 3
      state = %Raw{buffer: <<3>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: "c", modifiers: [:ctrl]}} = result
      assert new_state.buffer == <<>>
    end

    test "returns event from buffer with Alt+a" do
      # ESC followed by 'a' = Alt+a
      state = %Raw{buffer: <<27, ?a>>, event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a", modifiers: [:alt]}} = result
      assert new_state.buffer == <<>>
    end

    test "handles multiple characters in buffer by queueing" do
      # Buffer has 'abc' - should return first character and queue the rest
      state = %Raw{buffer: "abc", event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: "a", char: "a"}} = result
      # Remaining characters are queued as events
      assert new_state.buffer == <<>>
      assert length(new_state.event_queue) == 2
    end

    test "handles UTF-8 characters in buffer" do
      # UTF-8 encoded character (e.g., 'ñ')
      state = %Raw{buffer: "ñ", event_queue: [], reader_task: nil}

      {result, new_state} = Raw.poll(state, 0)

      assert {:ok, %Event.Key{key: "ñ", char: "ñ"}} = result
      assert new_state.buffer == <<>>
    end
  end

  describe "poll/2 with partial escape sequences" do
    test "returns timeout with partial escape sequence and 0 timeout" do
      # Just ESC - partial sequence
      state = %Raw{buffer: <<27>>, event_queue: [], reader_task: nil}

      # With 0 timeout, should return timeout since we can't complete sequence
      {result, _new_state} = Raw.poll(state, 0)

      assert result == :timeout
    end

    test "returns timeout with ESC[ partial sequence and 0 timeout" do
      # ESC [ - partial CSI sequence
      state = %Raw{buffer: <<27, ?[>>, event_queue: [], reader_task: nil}

      {result, _new_state} = Raw.poll(state, 0)

      assert result == :timeout
    end
  end

  describe "poll/2 return format" do
    test "returns tuple with result and new state" do
      state = %Raw{buffer: "x", event_queue: [], reader_task: nil}

      result = Raw.poll(state, 0)

      assert {_, %Raw{}} = result
    end

    test "result is {:ok, event} for successful parse" do
      state = %Raw{buffer: "x", event_queue: [], reader_task: nil}

      {{:ok, event}, _state} = Raw.poll(state, 0)

      assert %Event.Key{} = event
    end
  end

  describe "poll/2 with empty buffer" do
    test "returns timeout with 0ms timeout and empty buffer" do
      state = Raw.new()

      # This will try to read with 0 timeout, which should timeout immediately
      # Note: This test may be flaky if stdin has data
      {result, new_state} = Raw.poll(state, 0)

      # Should timeout since there's no input and timeout is 0
      assert result == :timeout
      assert %Raw{} = new_state
    end
  end

  describe "state management" do
    test "state is properly updated after poll with queued events" do
      state = %Raw{buffer: "abc", event_queue: [], reader_task: nil}

      # Poll should consume 'a' and queue 'b' and 'c' as events
      {_, new_state} = Raw.poll(state, 0)

      assert new_state.buffer == <<>>
      assert length(new_state.event_queue) == 2
    end

    test "multiple polls consume queued events sequentially" do
      state = %Raw{buffer: "xyz", event_queue: [], reader_task: nil}

      {{:ok, event1}, state} = Raw.poll(state, 0)
      assert event1.key == "x"

      {{:ok, event2}, state} = Raw.poll(state, 0)
      assert event2.key == "y"

      {{:ok, event3}, state} = Raw.poll(state, 0)
      assert event3.key == "z"

      # Both buffer and event_queue should now be empty
      assert state.buffer == <<>>
      assert state.event_queue == []
    end

    test "returns queued events before reading buffer" do
      # Pre-queue some events
      queued_event = Event.key(:queued_test)
      state = %Raw{buffer: "a", event_queue: [queued_event], reader_task: nil}

      # Should return queued event first
      {{:ok, event1}, state} = Raw.poll(state, 0)
      assert event1.key == :queued_test

      # Then buffer event
      {{:ok, event2}, _state} = Raw.poll(state, 0)
      assert event2.key == "a"
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Raw)
      assert is_binary(moduledoc)
      assert String.contains?(moduledoc, "Raw")
    end

    test "moduledoc mentions non-blocking input" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Raw)
      assert String.contains?(moduledoc, "Non-blocking")
    end

    test "moduledoc mentions escape sequences" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Raw)
      assert String.contains?(moduledoc, "escape sequence") or
               String.contains?(moduledoc, "Escape sequence")
    end

    test "poll/2 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      poll_doc =
        Enum.find(docs, fn
          {{:function, :poll, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert poll_doc != nil
    end

    test "mode/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      mode_doc =
        Enum.find(docs, fn
          {{:function, :mode, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert mode_doc != nil
    end

    test "new/0 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      new_doc =
        Enum.find(docs, fn
          {{:function, :new, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert new_doc != nil
    end
  end
end
