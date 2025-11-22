defmodule TermUI.Test.Components do
  @moduledoc """
  Shared test components for integration testing.

  These components are designed to work with ComponentHarness and use
  a simplified API (bare maps instead of {:ok, state} tuples).
  """

  defmodule Counter do
    @moduledoc """
    Simple counter component for testing state updates.
    """
    import TermUI.Component.Helpers

    alias TermUI.Event

    def init(props) do
      %{count: Keyword.get(props, :initial, 0)}
    end

    def render(state) do
      text("Count: #{state.count}")
    end

    def handle_event(%Event.Key{key: :up}, state) do
      {:noreply, %{state | count: state.count + 1}}
    end

    def handle_event(%Event.Key{key: :down}, state) do
      {:noreply, %{state | count: max(0, state.count - 1)}}
    end

    def handle_event(_event, state) do
      {:noreply, state}
    end
  end

  defmodule TextInput do
    @moduledoc """
    Simple text input component for testing character input.
    """
    import TermUI.Component.Helpers

    alias TermUI.Event

    def init(_props), do: %{text: ""}

    def render(state), do: text(state.text)

    def handle_event(%Event.Key{char: char}, state) when char != nil do
      {:noreply, %{state | text: state.text <> char}}
    end

    def handle_event(_event, state), do: {:noreply, state}
  end

  defmodule Label do
    @moduledoc """
    Simple label component for testing static text display.
    """
    import TermUI.Component.Helpers

    def init(props), do: %{text: Keyword.get(props, :text, "")}
    def render(state), do: text(state.text)
  end

  defmodule Toggle do
    @moduledoc """
    Simple toggle component for testing boolean state.
    """
    import TermUI.Component.Helpers

    alias TermUI.Event

    def init(props), do: %{enabled: Keyword.get(props, :enabled, false)}

    def render(state) do
      text(if state.enabled, do: "[x] Enabled", else: "[ ] Disabled")
    end

    def handle_event(%Event.Key{key: :enter}, state) do
      {:noreply, %{state | enabled: not state.enabled}}
    end

    def handle_event(_event, state), do: {:noreply, state}
  end
end
