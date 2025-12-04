defmodule TermUI.Backend.Config do
  @moduledoc """
  Configuration handling for terminal backends.

  The Config module provides a clean interface for reading backend configuration
  from the application environment. All configuration options have sensible
  defaults, allowing TermUI to work out of the box without explicit configuration.

  ## Configuration Options

  Configure TermUI in your `config/config.exs`:

      config :term_ui,
        backend: :auto,
        character_set: :unicode,
        fallback_character_set: :ascii,
        tty_opts: [line_mode: :full_redraw],
        raw_opts: [alternate_screen: true]

  ### Backend Selection

  The `:backend` option controls how the terminal backend is selected:

  - `:auto` (default) - Automatically detect the best backend using the selector
  - `TermUI.Backend.Raw` - Force raw mode backend
  - `TermUI.Backend.TTY` - Force TTY mode backend
  - `TermUI.Backend.Test` - Use test backend for testing

  ### Character Set

  The `:character_set` option specifies the preferred character set for
  rendering box-drawing characters and other UI elements:

  - `:unicode` (default) - Use Unicode box-drawing characters
  - `:ascii` - Use ASCII-only characters

  The `:fallback_character_set` option specifies what to use when the
  preferred character set is not available:

  - `:ascii` (default) - Fall back to ASCII
  - `:unicode` - Fall back to Unicode (rarely useful)

  ### Backend Options

  The `:tty_opts` and `:raw_opts` options pass backend-specific configuration:

  **TTY Options:**
  - `:line_mode` - Rendering mode (`:full_redraw` or `:incremental`)

  **Raw Options:**
  - `:alternate_screen` - Whether to use alternate screen buffer (boolean)

  ## Usage

      # Get individual configuration values
      backend = Config.get_backend()
      char_set = Config.get_character_set()

      # Get backend-specific options
      tty_opts = Config.get_tty_opts()
      raw_opts = Config.get_raw_opts()
  """

  @app :term_ui

  @doc """
  Returns the configured backend selection mode.

  ## Returns

  - `:auto` - Use automatic backend detection (default)
  - A module atom - Use the specified backend module

  ## Examples

      iex> Config.get_backend()
      :auto

      # With config: [backend: TermUI.Backend.Raw]
      iex> Config.get_backend()
      TermUI.Backend.Raw
  """
  @spec get_backend() :: :auto | module()
  def get_backend do
    Application.get_env(@app, :backend, :auto)
  end

  @doc """
  Returns the configured character set for UI rendering.

  ## Returns

  - `:unicode` - Use Unicode characters (default)
  - `:ascii` - Use ASCII-only characters

  ## Examples

      iex> Config.get_character_set()
      :unicode

      # With config: [character_set: :ascii]
      iex> Config.get_character_set()
      :ascii
  """
  @spec get_character_set() :: :unicode | :ascii
  def get_character_set do
    Application.get_env(@app, :character_set, :unicode)
  end

  @doc """
  Returns the configured fallback character set.

  Used when the preferred character set is not available on the terminal.

  ## Returns

  - `:ascii` - Fall back to ASCII (default)
  - `:unicode` - Fall back to Unicode

  ## Examples

      iex> Config.get_fallback_character_set()
      :ascii

      # With config: [fallback_character_set: :unicode]
      iex> Config.get_fallback_character_set()
      :unicode
  """
  @spec get_fallback_character_set() :: :unicode | :ascii
  def get_fallback_character_set do
    Application.get_env(@app, :fallback_character_set, :ascii)
  end

  @doc """
  Returns the configured TTY backend options.

  ## Returns

  A keyword list of TTY-specific options. Defaults to `[line_mode: :full_redraw]`.

  ## Options

  - `:line_mode` - Rendering mode
    - `:full_redraw` - Redraw entire screen each frame (default)
    - `:incremental` - Only redraw changed lines

  ## Examples

      iex> Config.get_tty_opts()
      [line_mode: :full_redraw]

      # With config: [tty_opts: [line_mode: :incremental]]
      iex> Config.get_tty_opts()
      [line_mode: :incremental]
  """
  @spec get_tty_opts() :: keyword()
  def get_tty_opts do
    Application.get_env(@app, :tty_opts, line_mode: :full_redraw)
  end

  @doc """
  Returns the configured raw backend options.

  ## Returns

  A keyword list of raw mode-specific options. Defaults to `[alternate_screen: true]`.

  ## Options

  - `:alternate_screen` - Whether to use the alternate screen buffer
    - `true` - Use alternate screen, restoring original on exit (default)
    - `false` - Use main screen buffer

  ## Examples

      iex> Config.get_raw_opts()
      [alternate_screen: true]

      # With config: [raw_opts: [alternate_screen: false]]
      iex> Config.get_raw_opts()
      [alternate_screen: false]
  """
  @spec get_raw_opts() :: keyword()
  def get_raw_opts do
    Application.get_env(@app, :raw_opts, alternate_screen: true)
  end
end
