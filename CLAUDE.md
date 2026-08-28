# Repository contributor guide

TermUI is a direct-mode terminal UI framework for Elixir/BEAM. This branch is
the stabilized 1.0 release line, not the proposed 2.0 rewrite.

## Current 1.0 architecture

- `TermUI.Runtime` is one GenServer that owns one `TermUI.Elm` root and its
  state. The root implements `init/1`, `event_to_msg/2`, `update/2`, and
  `view/1`.
- Interactive widgets implement `TermUI.StatefulComponent` as explicit state
  machines. The Elm root initializes them, retains their state, forwards
  relevant events, and renders them. The runtime does not create a process per
  widget or route focus through a component tree.
- `ComponentSupervisor`, `ComponentServer`, the registry, event router, focus
  manager, spatial index, and state persistence are lower-level standalone
  facilities. They are not wired into the main runtime automatically.
- The dirty render loop runs at roughly 60 FPS when work is pending. Raw and
  custom backends use differential buffer output; TTY renders a complete frame.
- Layout uses `TermUI.Layout.Constraint`, the solver, and stack child tuples.
  It is a deterministic constraint allocator, not a Cassowary implementation.

Start with `README.md`, `guides/component_system.md`, and
`guides/developer/01-architecture-overview.md`. Files under `notes/` are
historical planning, research, review, and implementation records; they are not
authoritative descriptions of the current system.

## Backends and platforms

- Elixir 1.15+ and OTP 26+ are supported for the TTY path.
- The native Raw backend requires OTP 28+ and a supported local Unix terminal.
- Raw is selected automatically when available; otherwise local operation falls
  back to TTY. IEx uses TTY.
- SSH/custom backends are supplied explicitly by the host per runtime session.
- Native Windows raw input, resize, and console-mode setup are not implemented
  in 1.0. Mouse tracking is disabled under WSL/ConPTY.

See `guides/user/08-terminal.md`, `guides/developer/06-terminal-layer.md`, and
`docs/widget-compatibility.md` for the detailed support contract.

## Validation

Before committing a release change, run checks appropriate to its scope. The
complete release gate is:

```bash
mix deps.get
mix format --check-formatted
MIX_ENV=test mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix deps.unlock --check-unused
mix hex.audit
mix deps.audit
```

Interactive terminal behavior also requires the applicable checklist under
`test/manual/`. Do not describe a waived platform check as verified.

## Working conventions

- Preserve unrelated changes in a dirty worktree.
- Add or update tests when changing behavior.
- Keep public module documentation and the guides aligned with executable APIs.
- Never mention Claude or any AI assistant in commit messages.
- The files under `.claude/` are legacy repository-local workflow templates,
  not product architecture or release documentation.
