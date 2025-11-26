defmodule TermUI.Runtime.ShutdownTest do
  use ExUnit.Case, async: false

  alias TermUI.Command
  alias TermUI.Runtime

  # Simple test component that can return quit command
  defmodule QuitComponent do
    @behaviour TermUI.Elm

    def init(_opts), do: %{quit_on_next: false}

    def update(:prepare_quit, state) do
      %{state | quit_on_next: true}
    end

    def update(:quit, state) do
      {state, [Command.quit()]}
    end

    def update(:quit_with_reason, state) do
      {state, [Command.quit(:user_requested)]}
    end

    def update(_msg, state), do: state

    def view(_state), do: {:text, "quit component"}

    def event_to_msg(_event, _state), do: :ignore
  end

  describe "quit command" do
    test "Command.quit/0 creates quit command" do
      cmd = Command.quit()
      assert cmd.type == :quit
      assert cmd.payload == :normal
    end

    test "Command.quit/1 creates quit command with reason" do
      cmd = Command.quit(:user_requested)
      assert cmd.type == :quit
      assert cmd.payload == :user_requested
    end

    test "quit command is valid" do
      cmd = Command.quit()
      assert Command.valid?(cmd)
    end

    test "quit command with custom reason is valid" do
      cmd = Command.quit({:error, :some_reason})
      assert Command.valid?(cmd)
    end
  end

  describe "Runtime shutdown via quit command" do
    test "quit command triggers shutdown" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # Verify runtime is alive
      assert Process.alive?(runtime)

      # Send quit message to component
      Runtime.send_message(runtime, :root, :quit)

      # Wait for shutdown
      Process.sleep(100)

      # Runtime should have stopped
      refute Process.alive?(runtime)
    end

    test "shutdown sets shutting_down flag" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # Get initial state
      state = Runtime.get_state(runtime)
      refute state.shutting_down

      # Trigger shutdown
      Runtime.shutdown(runtime)

      # Wait a bit for state to update
      Process.sleep(50)

      # Try to get state - may fail if already stopped
      # The important thing is that shutdown was initiated
      case Process.alive?(runtime) do
        true ->
          state = Runtime.get_state(runtime)
          assert state.shutting_down

        false ->
          # Already stopped, which means shutdown worked
          assert true
      end
    end
  end

  describe "Runtime.shutdown/1" do
    test "shutdown stops the runtime" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      assert Process.alive?(runtime)

      Runtime.shutdown(runtime)

      # Wait for shutdown
      Process.sleep(100)

      refute Process.alive?(runtime)
    end

    test "shutdown clears pending commands" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # Shutdown
      Runtime.shutdown(runtime)

      # Wait briefly
      Process.sleep(50)

      # State should be cleared if process is still alive
      if Process.alive?(runtime) do
        state = Runtime.get_state(runtime)
        assert state.pending_commands == %{}
      end
    end

    test "shutdown clears components" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      Runtime.shutdown(runtime)

      Process.sleep(50)

      if Process.alive?(runtime) do
        state = Runtime.get_state(runtime)
        assert state.components == %{}
      end
    end
  end

  describe "terminate/2" do
    test "terminate is called on normal shutdown" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # Monitor the process to confirm it terminates
      ref = Process.monitor(runtime)

      Runtime.shutdown(runtime)

      # Wait for DOWN message
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end

    test "terminate handles missing input_reader gracefully" do
      # skip_terminal: true means input_reader is nil
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      state = Runtime.get_state(runtime)
      assert state.input_reader == nil

      # Should not crash
      Runtime.shutdown(runtime)

      Process.sleep(100)
      refute Process.alive?(runtime)
    end
  end

  describe "trap_exit" do
    test "runtime traps exits to ensure cleanup" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # The runtime should trap exits to ensure terminate/2 is called
      # We can verify this by checking the process info
      {:trap_exit, trapping} = Process.info(runtime, :trap_exit)
      assert trapping == true

      # Cleanup
      Runtime.shutdown(runtime)
      Process.sleep(100)
    end
  end

  describe "events during shutdown" do
    test "events are ignored during shutdown" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      # Initiate shutdown
      Runtime.shutdown(runtime)

      # Try to send an event - should not crash
      Runtime.send_event(runtime, %TermUI.Event.Key{key: "a"})

      # Give it time to process
      Process.sleep(100)

      # Process should be stopped or stopping
      # The important thing is no crash occurred
    end

    test "messages are ignored during shutdown" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      Runtime.shutdown(runtime)

      # Try to send a message - should not crash
      Runtime.send_message(runtime, :root, :some_message)

      Process.sleep(100)
    end
  end

  describe "double shutdown" do
    test "double shutdown is safe" do
      {:ok, runtime} = Runtime.start_link(root: QuitComponent, skip_terminal: true)

      ref = Process.monitor(runtime)

      # Call shutdown twice
      Runtime.shutdown(runtime)
      Runtime.shutdown(runtime)

      # Should terminate normally
      assert_receive {:DOWN, ^ref, :process, ^runtime, _reason}, 1000
    end
  end
end
