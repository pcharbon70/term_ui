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

ExUnit.start(exclude: excludes)
