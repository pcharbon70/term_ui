defmodule TermUI.Theme do
  @moduledoc """
  Theme system for application-wide visual consistency.

  Themes define colors, semantic meanings, and component style defaults.
  The theme system supports runtime switching and notifies subscribers of changes.

  ## Theme Structure

  A theme contains:
  - `:name` - Theme identifier (e.g., `:dark`, `:light`)
  - `:colors` - Base colors (background, foreground, primary, etc.)
  - `:semantic` - Semantic colors (success, warning, error, etc.)
  - `:components` - Per-component style defaults

  ## Built-in Themes

  - `:dark` - Dark background with light text (default)
  - `:light` - Light background with dark text
  - `:high_contrast` - High contrast for accessibility

  ## Examples

      # Start theme server
      Theme.start_link(theme: :dark)

      # Get current theme
      theme = Theme.get_theme()

      # Switch themes at runtime
      Theme.set_theme(:light)

      # Subscribe to theme changes
      Theme.subscribe()
      receive do
        {:theme_changed, new_theme} -> handle_change(new_theme)
      end

      # Get colors
      bg = Theme.get_color(:background)
      error = Theme.get_semantic(:error)

      # Get component style
      style = Theme.get_component_style(:button, :focused)
  """

  use GenServer

  alias TermUI.Renderer.Style

  @type color :: Style.color()

  @type colors :: %{
          background: color(),
          foreground: color(),
          primary: color(),
          secondary: color(),
          accent: color()
        }

  @type semantic :: %{
          success: color(),
          warning: color(),
          error: color(),
          info: color(),
          muted: color(),
          help: color(),
          placeholder: color()
        }

  @type component_styles :: %{
          atom() => %{atom() => Style.t()}
        }

  @type t :: %__MODULE__{
          name: atom(),
          colors: colors(),
          semantic: semantic(),
          components: component_styles()
        }

  defstruct name: :custom,
            colors: %{},
            semantic: %{},
            components: %{}

  # ETS table for fast reads
  @ets_table :term_ui_theme

  # Dialyzer-typed style helpers to avoid opaque type warnings
  # These helpers provide type constraints for Style operations
  # We suppress dialyzer warnings because we know the color atoms are valid

  @dialyzer {:nowarn_function, fg_style: 1, fg_bg_style: 2, fg_bold: 1, fg_bg_bold: 2,
              fg_bold_underline: 1, fg_dim: 1, fg_underline: 1, fg_bg_reverse: 2,
              fg_bg_bold_reverse: 2, fg_bg_underline: 2, style_from_theme: 4}

  @doc false
  @spec fg_style(atom()) :: Style.t()
  defp fg_style(color) when is_atom(color), do: Style.new() |> Style.fg(color)

  @doc false
  @spec fg_bg_style(atom(), atom()) :: Style.t()
  defp fg_bg_style(fg_color, bg_color)
       when is_atom(fg_color) and is_atom(bg_color),
       do: Style.new() |> Style.fg(fg_color) |> Style.bg(bg_color)

  @doc false
  @spec fg_bold(atom()) :: Style.t()
  defp fg_bold(color) when is_atom(color), do: Style.new() |> Style.fg(color) |> Style.bold()

  @doc false
  @spec fg_bg_bold(atom(), atom()) :: Style.t()
  defp fg_bg_bold(fg_color, bg_color)
       when is_atom(fg_color) and is_atom(bg_color),
       do: Style.new() |> Style.fg(fg_color) |> Style.bg(bg_color) |> Style.bold()

  @doc false
  @spec fg_bold_underline(atom()) :: Style.t()
  defp fg_bold_underline(color) when is_atom(color),
    do: Style.new() |> Style.fg(color) |> Style.bold() |> Style.underline()

  @doc false
  @spec fg_dim(atom()) :: Style.t()
  defp fg_dim(color) when is_atom(color), do: Style.new() |> Style.fg(color) |> Style.dim()

  @doc false
  @spec fg_underline(atom()) :: Style.t()
  defp fg_underline(color) when is_atom(color),
    do: Style.new() |> Style.fg(color) |> Style.underline()

  @doc false
  @spec fg_bg_reverse(atom(), atom()) :: Style.t()
  defp fg_bg_reverse(fg_color, bg_color)
       when is_atom(fg_color) and is_atom(bg_color),
       do: Style.new() |> Style.fg(fg_color) |> Style.bg(bg_color) |> Style.reverse()

  @doc false
  @spec fg_bg_bold_reverse(atom(), atom()) :: Style.t()
  defp fg_bg_bold_reverse(fg_color, bg_color)
       when is_atom(fg_color) and is_atom(bg_color),
       do: Style.new() |> Style.fg(fg_color) |> Style.bg(bg_color) |> Style.bold() |> Style.reverse()

  @doc false
  @spec fg_bg_underline(atom(), atom()) :: Style.t()
  defp fg_bg_underline(fg_color, bg_color)
       when is_atom(fg_color) and is_atom(bg_color),
       do: Style.new() |> Style.fg(fg_color) |> Style.bg(bg_color) |> Style.underline()

  # Built-in theme definitions as functions (to avoid compile-time struct issues)

  defp dark_theme do
    %__MODULE__{
      name: :dark,
      colors: %{
        background: :black,
        foreground: :white,
        primary: :blue,
        secondary: :cyan,
        accent: :magenta
      },
      semantic: %{
        success: :green,
        warning: :yellow,
        error: :red,
        info: :cyan,
        muted: :bright_black,
        help: :white,
        placeholder: :bright_black
      },
      components: %{
        button: %{
          normal: fg_bg_style(:white, :bright_black),
          focused: fg_bg_bold(:white, :blue),
          disabled: fg_bg_style(:bright_black, :black)
        },
        text_input: %{
          normal: fg_bg_style(:white, :bright_black),
          focused: fg_bg_style(:white, :blue),
          disabled: fg_bg_style(:bright_black, :black)
        },
        text: %{
          normal: fg_style(:white),
          muted: fg_style(:bright_black),
          emphasis: fg_bold(:white)
        },
        border: %{
          normal: fg_style(:bright_black),
          focused: fg_style(:blue),
          accent: fg_style(:magenta)
        },
        item: %{
          normal: fg_style(:white),
          selected: fg_bg_bold_reverse(:black, :cyan),
          focused: fg_bg_bold(:white, :blue)
        },
        divider: %{
          normal: fg_style(:white),
          focused: fg_bg_bold_reverse(:white, :cyan)
        },
        status: %{
          running: fg_style(:green),
          warning: fg_bold(:yellow),
          error: fg_underline(:red),
          terminated: fg_underline(:red),
          unknown: fg_dim(:white)
        }
      }
    }
  end

  defp light_theme do
    %__MODULE__{
      name: :light,
      colors: %{
        background: :white,
        foreground: :black,
        primary: :blue,
        secondary: :cyan,
        accent: :magenta
      },
      semantic: %{
        success: :green,
        warning: :yellow,
        error: :red,
        info: :blue,
        muted: :bright_black,
        help: :black,
        placeholder: :bright_black
      },
      components: %{
        button: %{
          normal: fg_bg_style(:black, :white),
          focused: fg_bg_bold(:white, :blue),
          disabled: fg_bg_style(:bright_black, :white)
        },
        text_input: %{
          normal: fg_bg_style(:black, :white),
          focused: fg_bg_style(:black, :cyan),
          disabled: fg_bg_style(:bright_black, :white)
        },
        text: %{
          normal: fg_style(:black),
          muted: fg_style(:bright_black),
          emphasis: fg_bold(:black)
        },
        border: %{
          normal: fg_style(:bright_black),
          focused: fg_style(:blue),
          accent: fg_style(:magenta)
        },
        item: %{
          normal: fg_style(:black),
          selected: fg_bg_reverse(:black, :cyan),
          focused: fg_bg_bold(:white, :blue)
        },
        divider: %{
          normal: fg_style(:black),
          focused: fg_bg_bold_reverse(:black, :cyan)
        },
        status: %{
          running: fg_style(:green),
          warning: fg_bold(:yellow),
          error: fg_underline(:red),
          terminated: fg_underline(:red),
          unknown: fg_dim(:black)
        }
      }
    }
  end

  defp high_contrast_theme do
    %__MODULE__{
      name: :high_contrast,
      colors: %{
        background: :black,
        foreground: :bright_white,
        primary: :bright_cyan,
        secondary: :bright_yellow,
        accent: :bright_magenta
      },
      semantic: %{
        success: :bright_green,
        warning: :bright_yellow,
        error: :bright_red,
        info: :bright_cyan,
        muted: :white,
        help: :bright_white,
        placeholder: :white
      },
      components: %{
        button: %{
          normal: fg_bg_bold(:bright_white, :black),
          focused: fg_bg_bold(:black, :bright_cyan),
          disabled: fg_bg_style(:white, :black)
        },
        text_input: %{
          normal: fg_bg_underline(:bright_white, :black),
          focused: fg_bg_bold(:black, :bright_yellow),
          disabled: fg_bg_style(:white, :black)
        },
        text: %{
          normal: fg_style(:bright_white),
          muted: fg_style(:white),
          emphasis: fg_bold(:bright_yellow)
        },
        border: %{
          normal: fg_style(:white),
          focused: fg_bold(:bright_cyan),
          accent: fg_style(:bright_magenta)
        },
        item: %{
          normal: fg_style(:bright_white),
          selected: fg_bg_bold_reverse(:black, :bright_cyan),
          focused: fg_bg_bold(:black, :bright_yellow)
        },
        divider: %{
          normal: fg_style(:white),
          focused: fg_bg_bold_reverse(:white, :bright_cyan)
        },
        status: %{
          running: fg_bold(:bright_green),
          warning: fg_bold(:bright_yellow),
          error: fg_bold_underline(:bright_red),
          terminated: fg_bold_underline(:bright_red),
          unknown: fg_dim(:bright_white)
        }
      }
    }
  end

  defp builtin_themes do
    %{
      dark: dark_theme(),
      light: light_theme(),
      high_contrast: high_contrast_theme()
    }
  end

  # Public API - Server Management

  @doc """
  Starts the theme server.

  ## Options

  - `:theme` - Initial theme (atom name or Theme struct, default `:dark`)
  - `:name` - GenServer name (default `#{__MODULE__}`)

  ## Examples

      Theme.start_link(theme: :dark)
      Theme.start_link(theme: :light, name: MyApp.Theme)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the current theme.
  """
  @spec get_theme(GenServer.server()) :: t()
  def get_theme(server \\ __MODULE__) do
    table = ets_table(server)

    case :ets.whereis(table) do
      :undefined ->
        # Table doesn't exist, check if GenServer is running
        case Process.whereis(server) do
          nil ->
            # Neither table nor GenServer exist, return default theme
            dark_theme()

          _pid ->
            # GenServer is running, call it
            try do
              GenServer.call(server, :get_theme)
            catch
              :exit, _ -> dark_theme()
            end
        end

      _ref ->
        # Table exists, try to lookup
        case :ets.lookup(table, :current_theme) do
          [{:current_theme, theme}] -> theme
          [] -> GenServer.call(server, :get_theme)
        end
    end
  end

  @doc """
  Sets the current theme.

  Accepts a theme name atom (for built-in themes) or a Theme struct.
  Notifies all subscribers of the change.

  ## Examples

      Theme.set_theme(:light)
      Theme.set_theme(%Theme{name: :custom, ...})
  """
  @spec set_theme(atom() | t(), GenServer.server()) :: :ok | {:error, term()}
  def set_theme(theme, server \\ __MODULE__)

  def set_theme(name, server) when is_atom(name) do
    case get_builtin(name) do
      {:ok, theme} -> GenServer.call(server, {:set_theme, theme})
      {:error, _} = error -> error
    end
  end

  def set_theme(%__MODULE__{} = theme, server) do
    GenServer.call(server, {:set_theme, theme})
  end

  @doc """
  Subscribes the calling process to theme change notifications.

  Subscribers receive `{:theme_changed, theme}` messages when the theme changes.
  """
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server \\ __MODULE__) do
    GenServer.call(server, {:subscribe, self()})
  end

  @doc """
  Unsubscribes the calling process from theme change notifications.
  """
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(server \\ __MODULE__) do
    GenServer.call(server, {:unsubscribe, self()})
  end

  # Public API - Theme Values

  @doc """
  Gets a base color from the current theme.

  ## Examples

      Theme.get_color(:background)  # => :black
      Theme.get_color(:primary)     # => :blue
  """
  @spec get_color(atom(), GenServer.server()) :: color() | nil
  def get_color(name, server \\ __MODULE__) do
    theme = get_theme(server)
    Map.get(theme.colors, name)
  end

  @doc """
  Gets a semantic color from the current theme.

  ## Examples

      Theme.get_semantic(:error)    # => :red
      Theme.get_semantic(:success)  # => :green
  """
  @spec get_semantic(atom(), GenServer.server()) :: color() | nil
  def get_semantic(name, server \\ __MODULE__) do
    theme = get_theme(server)
    Map.get(theme.semantic, name)
  end

  @doc """
  Gets a component style from the current theme.

  ## Examples

      Theme.get_component_style(:button, :focused)
      Theme.get_component_style(:text_input, :normal)
  """
  @spec get_component_style(atom(), atom(), GenServer.server()) :: Style.t() | nil
  def get_component_style(component, variant, server \\ __MODULE__) do
    theme = get_theme(server)

    case Map.get(theme.components, component) do
      nil -> nil
      variants -> Map.get(variants, variant)
    end
  end

  @doc """
  Creates a style from theme values with optional overrides.

  Useful for components that want to use theme defaults but allow customization.

  ## Examples

      # Use theme button style as base, override foreground
      style = Theme.style_from_theme(:button, :normal, fg: :red)
  """
  @spec style_from_theme(atom(), atom(), keyword(), GenServer.server()) :: Style.t()
  def style_from_theme(component, variant, overrides \\ [], server \\ __MODULE__) do
    base = get_component_style(component, variant, server) || Style.new()
    override_style = Style.new(overrides)
    Style.merge(base, override_style)
  end

  # Public API - Theme Management

  @doc """
  Gets a built-in theme by name.
  """
  @spec get_builtin(atom()) :: {:ok, t()} | {:error, :not_found}
  def get_builtin(name) do
    case Map.get(builtin_themes(), name) do
      nil -> {:error, :not_found}
      theme -> {:ok, theme}
    end
  end

  @doc """
  Lists all available built-in themes.
  """
  @spec list_builtin() :: [atom()]
  def list_builtin do
    Map.keys(builtin_themes())
  end

  @doc """
  Creates a theme from a keyword list or map, merging with a base theme.

  ## Options

  - `:base` - Base theme to merge with (default `:dark`)
  - `:name` - Theme name
  - `:colors` - Color overrides
  - `:semantic` - Semantic color overrides
  - `:components` - Component style overrides

  ## Examples

      # Create custom theme based on dark
      {:ok, theme} = Theme.from(
        base: :dark,
        name: :my_theme,
        colors: %{primary: :magenta}
      )
  """
  @spec from(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def from(opts) when is_list(opts) or is_map(opts) do
    opts = if is_map(opts), do: Map.to_list(opts), else: opts

    base_name = Keyword.get(opts, :base, :dark)

    case get_builtin(base_name) do
      {:ok, base} ->
        theme = merge_theme(base, opts)
        {:ok, theme}

      {:error, _} ->
        {:error, {:invalid_base_theme, base_name}}
    end
  end

  @doc """
  Validates a theme struct.

  Returns `:ok` if valid, `{:error, reasons}` if invalid.
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = theme) do
    errors = []

    # Check required color fields
    required_colors = [:background, :foreground, :primary, :secondary, :accent]

    missing_colors =
      Enum.filter(required_colors, fn key ->
        not Map.has_key?(theme.colors, key)
      end)

    errors =
      if missing_colors != [] do
        ["Missing required colors: #{inspect(missing_colors)}" | errors]
      else
        errors
      end

    # Check required semantic fields
    required_semantic = [:success, :warning, :error, :info, :muted, :help, :placeholder]

    missing_semantic =
      Enum.filter(required_semantic, fn key ->
        not Map.has_key?(theme.semantic, key)
      end)

    errors =
      if missing_semantic != [] do
        ["Missing required semantic colors: #{inspect(missing_semantic)}" | errors]
      else
        errors
      end

    if errors == [] do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    # Create ETS table for fast reads
    table = create_ets_table(opts)

    # Get initial theme
    initial_theme = resolve_initial_theme(opts)

    # Store in ETS
    :ets.insert(table, {:current_theme, initial_theme})

    state = %{
      table: table,
      theme: initial_theme,
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_theme, _from, state) do
    {:reply, state.theme, state}
  end

  def handle_call({:set_theme, theme}, _from, state) do
    # Update ETS
    :ets.insert(state.table, {:current_theme, theme})

    # Notify subscribers
    notify_subscribers(state.subscribers, theme)

    {:reply, :ok, %{state | theme: theme}}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  # Private Helpers

  defp create_ets_table(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    table_name = ets_table(name)

    :ets.new(table_name, [:named_table, :public, read_concurrency: true])
  end

  defp ets_table(server) when is_atom(server) do
    :"#{server}_ets"
  end

  defp ets_table(pid) when is_pid(pid) do
    @ets_table
  end

  defp resolve_initial_theme(opts) do
    case Keyword.get(opts, :theme, :dark) do
      name when is_atom(name) ->
        case get_builtin(name) do
          {:ok, theme} -> theme
          {:error, _} -> dark_theme()
        end

      %__MODULE__{} = theme ->
        theme
    end
  end

  defp merge_theme(base, opts) do
    name = Keyword.get(opts, :name, base.name)
    colors = deep_merge(base.colors, Keyword.get(opts, :colors, %{}))
    semantic = deep_merge(base.semantic, Keyword.get(opts, :semantic, %{}))
    components = merge_components(base.components, Keyword.get(opts, :components, %{}))

    %__MODULE__{
      name: name,
      colors: colors,
      semantic: semantic,
      components: components
    }
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override)
  end

  defp deep_merge(base, override) when is_map(base) and is_list(override) do
    Map.merge(base, Map.new(override))
  end

  defp merge_components(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _key, base_variants, override_variants ->
      Map.merge(base_variants, override_variants)
    end)
  end

  defp merge_components(base, override) when is_map(base) and is_list(override) do
    merge_components(base, Map.new(override))
  end

  defp notify_subscribers(subscribers, theme) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:theme_changed, theme})
    end)
  end
end
