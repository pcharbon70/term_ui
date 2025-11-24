defmodule TermUI.Runtime.ResizeTest do
  use ExUnit.Case, async: false

  alias TermUI.Runtime
  alias TermUI.Event

  # Simple test component
  defmodule TestComponent do
    @behaviour TermUI.Elm

    def init(_opts), do: %{resizes: []}

    def update({:resize, width, height}, state) do
      %{state | resizes: [{width, height} | state.resizes]}
    end

    def update(_msg, state), do: state

    def view(_state), do: TermUI.Elm.text("test")

    def event_to_msg(%Event.Resize{width: w, height: h}, _state) do
      {:msg, {:resize, w, h}}
    end

    def event_to_msg(_event, _state), do: :ignore
  end

  describe "resize handling" do
    test "Runtime handles terminal_resize message" do
      {:ok, runtime} = Runtime.start_link(root: TestComponent, skip_terminal: true)

      # Send resize message
      send(runtime, {:terminal_resize, {50, 100}})

      # Give it time to process
      Process.sleep(50)

      state = Runtime.get_state(runtime)

      # With skip_terminal: true, dimensions won't be updated
      # because handle_resize checks terminal_started
      # This tests that the message is handled without crashing
      assert state != nil

      Runtime.shutdown(runtime)
    end

    test "resize event is created with correct dimensions" do
      resize_event = Event.Resize.new(120, 40)

      assert resize_event.width == 120
      assert resize_event.height == 40
      assert is_integer(resize_event.timestamp)
    end
  end

  describe "Event.Resize struct" do
    test "has default values" do
      resize = %Event.Resize{}
      assert resize.width == 80
      assert resize.height == 24
    end

    test "new/2 creates event with dimensions" do
      resize = Event.Resize.new(200, 50)
      assert resize.width == 200
      assert resize.height == 50
    end

    test "new/3 accepts timestamp option" do
      resize = Event.Resize.new(100, 50, timestamp: 12345)
      assert resize.timestamp == 12345
    end
  end
end
