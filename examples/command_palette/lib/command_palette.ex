defmodule CommandPalette do
  @moduledoc """
  CommandPalette example entry point.
  """

  defdelegate run, to: CommandPalette.App
end
