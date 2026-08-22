# Contributing to TermUI

Use the `develop` branch as the pull request target. Keep changes focused and
include tests for behavior changes.

Before you submit a pull request, run:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix coveralls
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix hex.build
```

Terminal lifecycle changes also need a manual check in a real terminal. Verify
normal exit, application failure, backend failure, and forced process exit.
After each case, confirm that cooked input, the cursor, style, paste mode,
focus events, mouse tracking, and the active screen are restored.

The supported runtime matrix is Elixir 1.18.4 or later on OTP 28 or later. CI
tests the oldest supported pair and the current Elixir and OTP pairs.
