# Contributing to TermUI

Use the `develop` branch as the pull request target. Keep changes focused and
include tests for behavior changes.

Before you submit a pull request, run:

```bash
mix deps.get
mix quality
mix coveralls
mix deps.unlock --check-unused
mix hex.audit
mix docs --warnings-as-errors -f html
HEX_API_KEY=dry-run mix hex.publish --dry-run --yes
```

TermUI uses the shared v5 Jido CI, review, and release workflows. Dependabot
checks Mix and GitHub Actions dependencies each week. Use Conventional Commits.
Do not edit `CHANGELOG.md` in a normal pull request. `git_ops` creates release
notes from commit history during release preparation.

Terminal lifecycle changes also need a manual check in a real terminal. Verify
normal exit, application failure, backend failure, and forced process exit.
After each case, confirm that cooked input, the cursor, style, paste mode,
focus events, mouse tracking, and the active screen are restored.

The supported runtime matrix is Elixir 1.18.4 or later on OTP 28 or later. CI
tests Elixir 1.18.4, 1.19, and 1.20 on OTP 28, and Elixir 1.20 on OTP 29.

See [Package quality](guides/package-quality.md) for the Jido standard and the
documented compatibility exceptions.
