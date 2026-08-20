defmodule TermUI.Widget.StreamWidget do
  @moduledoc "Compatibility name for the pure `TermUI.Widget.Stream` view."

  @behaviour TermUI.Widget

  defdelegate init(opts), to: TermUI.Widget.Stream
  defdelegate update(event, state), to: TermUI.Widget.Stream
  defdelegate view(state, dimensions), to: TermUI.Widget.Stream
  defdelegate push(state, item), to: TermUI.Widget.Stream
end
