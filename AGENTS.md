# TermUI Agent Instructions

TermUI is a small Elm-style terminal runtime for Elixir and the BEAM.

Keep these runtime boundaries:

- One runtime process owns application state and update order.
- Application views return one complete `TermUI.Frame`.
- One backend owner controls terminal input, output, size, capabilities, and cleanup.
- Widgets are pure. The parent application owns widget state and effects.
- Commands are data values. Do not run effects in widget code.

Use `develop` as the pull request target. Preserve the public `TermUI` namespace
and the Jido Console runtime contract. Run `mix quality` and `mix coveralls`
before a commit. Terminal lifecycle changes also need a real terminal check.

Use Conventional Commits. Never mention an AI assistant in a commit message.
