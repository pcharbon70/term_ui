defmodule TermUI.RuntimeTestCase do
  @moduledoc """
  Test case helper for Runtime-based integration tests.

  Provides common setup, aliases, and helpers for testing components
  using the TermUI.Runtime with the Elm Architecture pattern.

  ## Usage

      defmodule MyIntegrationTest do
        use TermUI.RuntimeTestCase

        test "my component works" do
          runtime = start_test_runtime(MyComponent)

          Runtime.send_event(runtime, Event.key(:up))
          Runtime.sync(runtime)

          state = Runtime.get_state(runtime)
          assert state.root_state.count == 1
        end
      end

  ## Provided Helpers

  - `start_test_runtime/1` - Starts a runtime with automatic cleanup on test exit
  - Standard aliases for `Runtime`, `Event`, `Command`
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: false

      alias TermUI.Runtime
      alias TermUI.Event
      alias TermUI.Command

      @doc """
      Starts a runtime with the given component and automatic cleanup.

      The runtime is automatically shut down when the test exits, even if
      the test fails. This ensures no zombie processes are left behind.

      ## Example

          runtime = start_test_runtime(MyComponent)
          # runtime will be cleaned up automatically
      """
      defp start_test_runtime(component) do
        {:ok, runtime} = Runtime.start_link(root: component, skip_terminal: true)

        on_exit(fn ->
          if Process.alive?(runtime), do: Runtime.shutdown(runtime)
        end)

        runtime
      end
    end
  end
end
