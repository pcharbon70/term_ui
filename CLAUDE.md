# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TermUI is a direct-mode Terminal UI framework for Elixir/BEAM, currently in the research and design phase. The goal is to build a world-class TUI framework that leverages BEAM's unique strengths (fault tolerance, actor model, hot code reloading, distribution) while adopting proven patterns from modern TUI frameworks like BubbleTea (Go) and Ratatui (Rust).

## Target Architecture

The framework uses The Elm Architecture adapted for OTP with three abstraction layers:

1. **Port layer** - Low-level terminal interface (raw mode, escape sequences, capability detection)
2. **Renderer layer** - Virtual screen buffer with differential updates (ETS-based double buffering)
3. **Widget layer** - OTP-based component system with supervision

### Key Design Decisions

- **OTP 28+ only** - Uses native raw mode via `shell.start_interactive({:noshell, :raw})`
- **Process-per-component** for interactive widgets, shared state for static display elements
- **Framerate-limited rendering** (60 FPS default) with intelligent diffing
- **Cassowary constraint solver** for layouts with LRU caching
- **Commands pattern** for side effects (async operations return messages to update loop)

### Platform Targets

- Elixir 1.15+, OTP 28+
- Linux, macOS, Windows 10+
- Major terminals: Alacritty, Kitty, WezTerm, iTerm2, GNOME Terminal, Windows Terminal

## Project Status

Currently in research phase. The `notes/research/state_of_tui.md` contains comprehensive analysis of:
- Historical terminal architecture (terminfo, curses, VT100)
- Modern TUI frameworks (BubbleTea, Ratatui, Textual, FTXUI, etc.)
- BEAM-specific patterns (GenServer, Supervisors, GenStage, Ports vs NIFs)
- Direct mode programming requirements
- Proposed architecture and implementation roadmap

## Development Notes

When implementation begins, follow these patterns:

- Use **GenServer** for stateful widgets with clear message-based APIs
- Use **Supervisors** to mirror UI component hierarchies for fault isolation
- Prefer **Ports over NIFs** for terminal I/O (crash isolation)
- Use **ETS tables** for render buffers (`:screen_current`, `:screen_previous`)
- Implement **cursor optimization** (compare cost of absolute vs relative positioning)
- Support graceful degradation for terminal features (true color → 256 → 16 → mono)
- IMPORTANT you must NEVER mention Claude or any AI assistant in your commit messages!