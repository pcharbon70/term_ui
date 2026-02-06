# Conditionally exclude tests that require terminal and OTP 28+
terminal_available? =
  case :io.getopts(:standard_io) do
    {:ok, opts} -> Keyword.has_key?(opts, :terminal)
    _ -> false
  end

raw_mode_available? = function_exported?(:shell, :start_interactive, 1)

excludes =
  if terminal_available? and raw_mode_available? do
    []
  else
    [:requires_terminal]
  end
  |> Enum.uniq()

case :logger.remove_handler(:default) do
  :ok -> :ok
  {:error, _} -> :ok
end

case TermUI.Theme.start_link(theme: :dark) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

Application.put_env(:term_ui, :suppress_terminal_output, true)

ExUnit.start(
  exclude: excludes,
  capture_log: true,
  formatters: [TermUI.TestFormatter]
)
