# Package quality

TermUI follows the [Jido package quality standard](https://jido.run/docs/contributors/package-quality-standards)
where it does not conflict with the public TermUI contract. The shared
[`agentjido/github-actions`](https://github.com/agentjido/github-actions)
repository is the source of truth for workflow versions. TermUI uses the v5
callers because v5 is the current stable workflow contract. The standards page
still contains some older v4 examples.

## Compliance record

| Area | TermUI decision |
| --- | --- |
| Package identity | README, Hex metadata, guides, and module docs describe the Elm runtime and its use by Jido Console. |
| Repository files | `AGENTS.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, `usage-rules.md`, examples, guides, and environment config files are present. |
| Public data | Public boundary values use Zoi schemas. Private runtime and widget state uses plain structs. |
| Quality command | `mix quality` runs format, warning-free compile, xref cycle checks, strict Credo, Dialyzer, and Doctor. |
| Tests and coverage | `mix coveralls` runs deterministic tests and enforces at least 90% line coverage without excluding production modules. |
| CI | The v5 shared CI caller tests all supported Elixir lines on OTP 28 or 29. CI also checks audit, docs, package content, and unused dependencies. |
| Dependency updates | Dependabot checks Mix and GitHub Actions dependencies each week with Conventional Commit titles. |
| Releases | The v5 shared release caller uses `git_ops` for release preparation and Hex publication. |
| Review | The v5 shared advisory review caller checks pull requests to `develop`. |
| Examples | The runnable counter and showcase examples are outside `lib/` and have their own Mix projects. |
| Worktree safety | The package does not auto-install Git hooks and does not store local worktree paths. |

## Documented exceptions

- The public namespace stays `TermUI`, not `Jido.TermUI`. This preserves the
  upstream API and the Jido Console contract.
- TermUI keeps small tagged error tuples at backend and runtime boundaries. It
  does not add Splode during the release candidate because that would change
  the public failure contract.
- TermUI has no installer. It needs no project files, configuration, database
  changes, or generated code, so an Igniter installer would have no work to do.
- OTP 28 is the minimum runtime because native raw mode is part of the backend
  contract. CI does not claim support for OTP 27.
- `develop` is the default branch, so CI push and review filters use `develop`
  instead of the shared examples' `main` branch.

Review these exceptions before a stable 1.0 release. Do not remove them by
changing the runtime or public namespace in a quality-only change.
