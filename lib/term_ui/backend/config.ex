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

  ## Validation

  Use `validate!/0` to check configuration at application startup:

      # In your Application.start/2
      TermUI.Backend.Config.validate!()

  Or use `valid?/0` to check without raising:

      if Config.valid?() do
        # proceed
      else
        # handle invalid config
      end
  """

  @app :term_ui

  # Valid configuration values
  @valid_backends [:auto, TermUI.Backend.Raw, TermUI.Backend.TTY, TermUI.Backend.Test]
  @valid_character_sets [:unicode, :ascii]
  @valid_line_modes [:full_redraw, :incremental]

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

  # ============================================================================
  # Validation Functions
  # ============================================================================

  @doc """
  Validates the current configuration, raising on errors.

  Checks that all configuration values are valid. Call this at application
  startup to catch configuration errors early.

  ## Returns

  - `:ok` if configuration is valid

  ## Raises

  - `ArgumentError` with a descriptive message if any configuration is invalid

  ## Examples

      iex> Config.validate!()
      :ok

      # With invalid config: [backend: :invalid]
      iex> Config.validate!()
      ** (ArgumentError) invalid :backend value: :invalid, expected one of [:auto, TermUI.Backend.Raw, TermUI.Backend.TTY, TermUI.Backend.Test]
  """
  @spec validate!() :: :ok
  def validate! do
    validate_backend!()
    validate_character_set!()
    validate_fallback_character_set!()
    validate_tty_opts!()
    validate_raw_opts!()
    :ok
  end

  @doc """
  Checks if the current configuration is valid.

  Returns `true` if all configuration values are valid, `false` otherwise.
  Does not raise exceptions.

  ## Returns

  - `true` if configuration is valid
  - `false` if any configuration value is invalid

  ## Examples

      iex> Config.valid?()
      true

      # With invalid config: [backend: :invalid]
      iex> Config.valid?()
      false
  """
  @spec valid?() :: boolean()
  def valid? do
    validate!()
    true
  rescue
    ArgumentError -> false
  end

  @doc """
  Returns the complete runtime configuration as a map.

  This function validates the configuration before returning. If any
  configuration value is invalid, an `ArgumentError` is raised.

  ## Returns

  A map containing all configuration values:
  - `:backend` - Backend selection mode
  - `:character_set` - Preferred character set
  - `:fallback_character_set` - Fallback character set
  - `:tty_opts` - TTY backend options
  - `:raw_opts` - Raw backend options

  ## Raises

  - `ArgumentError` if any configuration value is invalid

  ## Examples

      iex> Config.runtime_config()
      %{
        backend: :auto,
        character_set: :unicode,
        fallback_character_set: :ascii,
        tty_opts: [line_mode: :full_redraw],
        raw_opts: [alternate_screen: true]
      }

      # With custom config
      iex> Config.runtime_config()
      %{
        backend: TermUI.Backend.Raw,
        character_set: :ascii,
        fallback_character_set: :ascii,
        tty_opts: [line_mode: :incremental],
        raw_opts: [alternate_screen: false]
      }
  """
  @spec runtime_config() :: %{
          backend: :auto | module(),
          character_set: :unicode | :ascii,
          fallback_character_set: :unicode | :ascii,
          tty_opts: keyword(),
          raw_opts: keyword()
        }
  def runtime_config do
    validate!()

    %{
      backend: get_backend(),
      character_set: get_character_set(),
      fallback_character_set: get_fallback_character_set(),
      tty_opts: get_tty_opts(),
      raw_opts: get_raw_opts()
    }
  end

  # Private validation helpers

  defp validate_backend! do
    backend = get_backend()

    unless backend in @valid_backends do
      raise ArgumentError,
            "invalid :backend value: #{inspect(backend)}, " <>
              "expected one of #{inspect(@valid_backends)}"
    end
  end

  defp validate_character_set! do
    char_set = get_character_set()

    unless char_set in @valid_character_sets do
      raise ArgumentError,
            "invalid :character_set value: #{inspect(char_set)}, " <>
              "expected one of #{inspect(@valid_character_sets)}"
    end
  end

  defp validate_fallback_character_set! do
    fallback = get_fallback_character_set()

    unless fallback in @valid_character_sets do
      raise ArgumentError,
            "invalid :fallback_character_set value: #{inspect(fallback)}, " <>
              "expected one of #{inspect(@valid_character_sets)}"
    end
  end

  defp validate_tty_opts! do
    opts = get_tty_opts()

    unless is_list(opts) do
      raise ArgumentError,
            "invalid :tty_opts value: #{inspect(opts)}, expected a keyword list"
    end

    if Keyword.has_key?(opts, :line_mode) do
      line_mode = Keyword.get(opts, :line_mode)

      unless line_mode in @valid_line_modes do
        raise ArgumentError,
              "invalid :line_mode value in :tty_opts: #{inspect(line_mode)}, " <>
                "expected one of #{inspect(@valid_line_modes)}"
      end
    end
  end

  defp validate_raw_opts! do
    opts = get_raw_opts()

    unless is_list(opts) do
      raise ArgumentError,
            "invalid :raw_opts value: #{inspect(opts)}, expected a keyword list"
    end
  end
end
