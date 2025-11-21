defmodule TermUI.ThemeTest do
  use ExUnit.Case, async: true

  alias TermUI.Theme
  alias TermUI.Style

  setup do
    # Start a unique theme server for each test
    name = :"theme_test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = Theme.start_link(name: name, theme: :dark)
    %{server: name, pid: pid}
  end

  describe "theme structure" do
    test "dark theme has all required color fields" do
      {:ok, theme} = Theme.get_builtin(:dark)

      assert theme.colors.background == :black
      assert theme.colors.foreground == :white
      assert theme.colors.primary == :blue
      assert theme.colors.secondary == :cyan
      assert theme.colors.accent == :magenta
    end

    test "dark theme has all required semantic fields" do
      {:ok, theme} = Theme.get_builtin(:dark)

      assert theme.semantic.success == :green
      assert theme.semantic.warning == :yellow
      assert theme.semantic.error == :red
      assert theme.semantic.info == :cyan
      assert theme.semantic.muted == :bright_black
    end

    test "theme has component styles" do
      {:ok, theme} = Theme.get_builtin(:dark)

      assert Map.has_key?(theme.components, :button)
      assert Map.has_key?(theme.components, :text_input)
      assert Map.has_key?(theme.components, :text)
      assert Map.has_key?(theme.components, :border)
    end

    test "component styles have variants" do
      {:ok, theme} = Theme.get_builtin(:dark)

      button = theme.components.button
      assert Map.has_key?(button, :normal)
      assert Map.has_key?(button, :focused)
      assert Map.has_key?(button, :disabled)
    end

    test "component variant styles are Style structs" do
      {:ok, theme} = Theme.get_builtin(:dark)

      style = theme.components.button.normal
      assert %Style{} = style
    end
  end

  describe "built-in themes" do
    test "dark theme loads correctly" do
      {:ok, theme} = Theme.get_builtin(:dark)
      assert theme.name == :dark
    end

    test "light theme loads correctly" do
      {:ok, theme} = Theme.get_builtin(:light)
      assert theme.name == :light
      assert theme.colors.background == :white
      assert theme.colors.foreground == :black
    end

    test "high_contrast theme loads correctly" do
      {:ok, theme} = Theme.get_builtin(:high_contrast)
      assert theme.name == :high_contrast
      assert theme.colors.foreground == :bright_white
    end

    test "invalid theme returns error" do
      assert {:error, :not_found} = Theme.get_builtin(:nonexistent)
    end

    test "list_builtin returns all theme names" do
      themes = Theme.list_builtin()
      assert :dark in themes
      assert :light in themes
      assert :high_contrast in themes
    end
  end

  describe "theme loading" do
    test "from/1 creates theme from keyword list" do
      {:ok, theme} = Theme.from(name: :custom, colors: %{primary: :magenta})

      assert theme.name == :custom
      assert theme.colors.primary == :magenta
      # Inherits other colors from dark (default base)
      assert theme.colors.background == :black
    end

    test "from/1 uses specified base theme" do
      {:ok, theme} = Theme.from(base: :light, name: :custom)

      assert theme.name == :custom
      assert theme.colors.background == :white
    end

    test "from/1 returns error for invalid base" do
      {:error, reason} = Theme.from(base: :invalid)
      assert {:invalid_base_theme, :invalid} = reason
    end

    test "from/1 merges semantic colors" do
      {:ok, theme} = Theme.from(semantic: %{error: :bright_red})

      assert theme.semantic.error == :bright_red
      # Others unchanged
      assert theme.semantic.success == :green
    end

    test "from/1 merges component styles" do
      custom_button = %{
        normal: Style.new() |> Style.fg(:cyan)
      }

      {:ok, theme} = Theme.from(components: %{button: custom_button})

      assert theme.components.button.normal.fg == :cyan
      # Other button variants preserved
      assert theme.components.button.focused != nil
    end
  end

  describe "theme validation" do
    test "valid theme passes validation" do
      {:ok, theme} = Theme.get_builtin(:dark)
      assert :ok = Theme.validate(theme)
    end

    test "theme missing colors fails validation" do
      theme = %Theme{
        name: :invalid,
        colors: %{background: :black},
        semantic: %{success: :green, warning: :yellow, error: :red, info: :cyan, muted: :white},
        components: %{}
      }

      {:error, errors} = Theme.validate(theme)
      assert length(errors) == 1
      assert hd(errors) =~ "Missing required colors"
    end

    test "theme missing semantic colors fails validation" do
      theme = %Theme{
        name: :invalid,
        colors: %{
          background: :black,
          foreground: :white,
          primary: :blue,
          secondary: :cyan,
          accent: :magenta
        },
        semantic: %{success: :green},
        components: %{}
      }

      {:error, errors} = Theme.validate(theme)
      assert length(errors) == 1
      assert hd(errors) =~ "Missing required semantic"
    end
  end

  describe "runtime theme switching" do
    test "get_theme returns current theme", %{server: server} do
      theme = Theme.get_theme(server)
      assert theme.name == :dark
    end

    test "set_theme changes current theme by name", %{server: server} do
      :ok = Theme.set_theme(:light, server)
      theme = Theme.get_theme(server)
      assert theme.name == :light
    end

    test "set_theme accepts Theme struct", %{server: server} do
      {:ok, custom} = Theme.from(name: :custom)
      :ok = Theme.set_theme(custom, server)

      theme = Theme.get_theme(server)
      assert theme.name == :custom
    end

    test "set_theme returns error for invalid theme name", %{server: server} do
      {:error, :not_found} = Theme.set_theme(:invalid, server)

      # Theme unchanged
      theme = Theme.get_theme(server)
      assert theme.name == :dark
    end
  end

  describe "theme subscriptions" do
    test "subscribers receive theme change notification", %{server: server} do
      :ok = Theme.subscribe(server)
      :ok = Theme.set_theme(:light, server)

      assert_receive {:theme_changed, theme}
      assert theme.name == :light
    end

    test "unsubscribe stops notifications", %{server: server} do
      :ok = Theme.subscribe(server)
      :ok = Theme.unsubscribe(server)
      :ok = Theme.set_theme(:light, server)

      refute_receive {:theme_changed, _}, 100
    end

    test "subscriber auto-unsubscribes on process death", %{server: server} do
      # Spawn a process that subscribes and dies
      test_pid = self()

      spawn(fn ->
        :ok = Theme.subscribe(server)
        send(test_pid, :subscribed)
      end)

      assert_receive :subscribed

      # Wait for process to die and be cleaned up
      Process.sleep(50)

      # Set theme should not error (no dead subscribers)
      :ok = Theme.set_theme(:light, server)
    end
  end

  describe "theme value access" do
    test "get_color returns base colors", %{server: server} do
      assert Theme.get_color(:background, server) == :black
      assert Theme.get_color(:primary, server) == :blue
    end

    test "get_color returns nil for unknown color", %{server: server} do
      assert Theme.get_color(:unknown, server) == nil
    end

    test "get_semantic returns semantic colors", %{server: server} do
      assert Theme.get_semantic(:error, server) == :red
      assert Theme.get_semantic(:success, server) == :green
    end

    test "get_semantic returns nil for unknown", %{server: server} do
      assert Theme.get_semantic(:unknown, server) == nil
    end

    test "get_component_style returns component variant", %{server: server} do
      style = Theme.get_component_style(:button, :focused, server)
      assert %Style{} = style
      assert Style.has_attr?(style, :bold)
    end

    test "get_component_style returns nil for unknown component", %{server: server} do
      assert Theme.get_component_style(:unknown, :normal, server) == nil
    end

    test "get_component_style returns nil for unknown variant", %{server: server} do
      assert Theme.get_component_style(:button, :unknown, server) == nil
    end
  end

  describe "style_from_theme" do
    test "returns base component style", %{server: server} do
      style = Theme.style_from_theme(:button, :normal, [], server)
      assert %Style{} = style
    end

    test "merges overrides with theme style", %{server: server} do
      style = Theme.style_from_theme(:button, :normal, [fg: :red], server)

      assert style.fg == :red
      # Background from theme
      assert style.bg != nil
    end

    test "returns styled override for unknown component", %{server: server} do
      style = Theme.style_from_theme(:unknown, :normal, [fg: :blue], server)

      assert style.fg == :blue
    end
  end

  describe "ETS caching" do
    test "theme is cached in ETS for fast reads", %{server: server} do
      # First read populates ETS
      theme1 = Theme.get_theme(server)

      # Subsequent reads come from ETS
      theme2 = Theme.get_theme(server)

      assert theme1 == theme2
    end

    test "set_theme updates ETS cache", %{server: server} do
      Theme.set_theme(:light, server)
      theme = Theme.get_theme(server)
      assert theme.name == :light
    end
  end

  describe "multiple servers" do
    test "independent theme servers maintain separate state" do
      {:ok, _} = Theme.start_link(name: :server_a, theme: :dark)
      {:ok, _} = Theme.start_link(name: :server_b, theme: :light)

      assert Theme.get_theme(:server_a).name == :dark
      assert Theme.get_theme(:server_b).name == :light
    end
  end

  describe "theme comparison" do
    test "built-in themes have distinct color schemes" do
      {:ok, dark} = Theme.get_builtin(:dark)
      {:ok, light} = Theme.get_builtin(:light)

      assert dark.colors.background != light.colors.background
      assert dark.colors.foreground != light.colors.foreground
    end

    test "high_contrast uses bright colors" do
      {:ok, theme} = Theme.get_builtin(:high_contrast)

      # High contrast uses bright variants
      assert theme.colors.foreground == :bright_white
      assert theme.semantic.success == :bright_green
      assert theme.semantic.error == :bright_red
    end
  end

  describe "edge cases" do
    test "empty overrides preserve base theme" do
      {:ok, theme} = Theme.from([])
      {:ok, dark} = Theme.get_builtin(:dark)

      assert theme.colors == dark.colors
      assert theme.semantic == dark.semantic
    end

    test "component merge preserves unmodified variants" do
      {:ok, theme} =
        Theme.from(
          components: %{
            button: %{
              normal: Style.new() |> Style.fg(:cyan)
            }
          }
        )

      # Modified variant
      assert theme.components.button.normal.fg == :cyan
      # Unmodified variants preserved
      assert theme.components.button.focused != nil
      assert theme.components.button.disabled != nil
    end
  end
end
