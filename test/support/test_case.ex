defmodule TermUI.TestCase do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)

      setup tags do
        TermUI.TestCase.configure_terminal_output(tags)
        :ok
      end
    end
  end

  def configure_terminal_output(tags) do
    if Map.get(tags, :allow_terminal_output, false) do
      TermUI.TerminalOutput.allow_current_process()
    else
      TermUI.TerminalOutput.disallow_current_process()
    end
  end
end
