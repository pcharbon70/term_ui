defmodule TermUI.Config do
  @moduledoc """
  Configuration reading and defaults for TermUI applications.

  This module provides application-level configuration for TermUI.
  Configuration is read from the application environment and can be
  overridden by runtime options.

  ## Configuration

  Add to your `config/config.exs`:

      import Config

      config :term_ui,
        backend: :auto,
        color_mode: :auto,
        character_set: :auto,
        render_interval: 16,
        iex_compatible: :auto

  ## Options

  ### `:backend`

  Controls which terminal backend to use.

  - `:auto` - (default) Automatically detect and use the best available backend
  - `:raw` - Force raw mode (requires OTP 28+, error if unavailable)
  - `:tty` - Force TTY mode (line-based input, no raw mode attempt)

  Example:
      config :term_ui, backend: :tty

  ### `:color_mode`

  Controls color depth preference.

  - `:auto` - (default) Detect terminal color support
  - `:true_color` - Force 24-bit RGB color
  - `:color_256` - Force 256-color palette
  - `:color_16` - Force 16-color palette
  - `:monochrome` - Force monochrome (no color)

  Example:
      config :term_ui, color_mode: :color_256

  ### `:character_set`

  Controls character set preference.

  - `:auto` - (default) Detect Unicode support
  - `:unicode` - Force Unicode character set
  - `:ascii` - Force ASCII character set

  Example:
      config :term_ui, character_set: :ascii

  ### `:render_interval`

  Milliseconds between renders.

  - Default: `16` (~60 FPS)
  - Lower values = smoother animations but more CPU usage
  - Higher values = less CPU but choppier animations

  Example:
      config :term_ui, render_interval: 33  # ~30 FPS

  ### `:iex_compatible`

  Controls IEx compatibility mode detection.

  - `:auto` - (default) Automatically detect if running in IEx
  - `true` - Force IEx-compatible mode
  - `false` - Force standalone mode

  This can also be controlled via the `TERM_UI_IEX_MODE` environment variable.

  Example:
      config :term_ui, iex_compatible: true

  To override via environment variable:
      export TERM_UI_IEX_MODE=true

  See `TermUI.iex_mode?/0` for more details on IEx detection.

  ## Runtime Options Override

  Runtime options passed to `TermUI.App.start/2` or `TermUI.App.run/2`
  always take precedence over configuration:

      # Config says :tty, but runtime option says :raw
      {:ok, _pid} = TermUI.App.start(MyApp, backend: :raw)

  ## Per-Environment Configuration

  You can configure different settings per environment:

      # config/dev.exs
      config :term_ui, backend: :raw

      # config/test.exs
      config :term_ui, backend: :tty

      # config/prod.exs
      config :term_ui, backend: :auto

  """

  @type option_key ::
          :backend
          | :color_mode
          | :character_set
          | :render_interval
          | :skip_terminal
          | :use_input_handler
          | :name

  @type option :: {option_key(), term()}

  @default_backend :auto
  @default_color_mode :auto
  @default_character_set :auto
  @default_render_interval 16

  @doc """
  Gets a configuration value by key with an optional default.

  ## Examples

      iex> TermUI.Config.get(:backend)
      :auto

      iex> TermUI.Config.get(:render_interval)
      16

      iex> Application.put_env(:term_ui, :backend, :tty)
      iex> TermUI.Config.get(:backend)
      :tty

  """
  @spec get(option_key(), term()) :: term()
  def get(key, default \\ nil)

  def get(:backend, default) do
    Application.get_env(:term_ui, :backend, default || @default_backend)
  end

  def get(:color_mode, default) do
    Application.get_env(:term_ui, :color_mode, default || @default_color_mode)
  end

  def get(:character_set, default) do
    Application.get_env(:term_ui, :character_set, default || @default_character_set)
  end

  def get(:render_interval, default) do
    Application.get_env(:term_ui, :render_interval, default || @default_render_interval)
  end

  def get(key, default) do
    Application.get_env(:term_ui, key, default)
  end

  @doc """
  Gets all configuration values as a keyword list.

  Returns the current application configuration merged with defaults.

  ## Examples

      iex> Keyword.keys(TermUI.Config.all())
      [:backend, :color_mode, :character_set, :render_interval]

  """
  @spec all() :: keyword()
  def all do
    [
      backend: get(:backend),
      color_mode: get(:color_mode),
      character_set: get(:character_set),
      render_interval: get(:render_interval)
    ]
  end

  @doc """
  Merges application configuration with runtime options.

  Runtime options take precedence over application configuration.
  This allows users to override config for specific cases.

  ## Priority

  1. Runtime options (highest)
  2. Application configuration
  3. Module defaults (lowest)

  ## Examples

      iex> TermUI.Config.merge_options([backend: :auto])
      [backend: :auto, render_interval: 16, ...]

      iex> TermUI.Config.merge_options(backend: :raw, render_interval: 33)
      [backend: :raw, render_interval: 33, ...]

      # Runtime option overrides config
      iex> Application.put_env(:term_ui, :backend, :tty)
      iex> opts = TermUI.Config.merge_options(backend: :raw)
      iex> opts[:backend]
      :raw

  """
  @spec merge_options(keyword()) :: keyword()
  def merge_options(runtime_opts \\ []) do
    config_opts = all()

    # Runtime options take precedence
    Keyword.merge(config_opts, runtime_opts)
  end

  @doc """
  Returns the default options without reading from application config.

  This is useful for testing or when you want to ignore application config.

  ## Examples

      iex> TermUI.Config.defaults()
      [backend: :auto, color_mode: :auto, character_set: :auto, render_interval: 16]

  """
  @spec defaults() :: keyword()
  def defaults do
    [
      backend: @default_backend,
      color_mode: @default_color_mode,
      character_set: @default_character_set,
      render_interval: @default_render_interval
    ]
  end
end
