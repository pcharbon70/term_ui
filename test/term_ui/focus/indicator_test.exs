defmodule TermUI.Focus.IndicatorTest do
  use ExUnit.Case, async: true

  alias TermUI.Focus.Indicator
  alias TermUI.Renderer.Style

  describe "default_style/0" do
    test "returns a style map" do
      style = Indicator.default_style()

      assert is_map(style)
      assert Map.has_key?(style, :fg)
      assert Map.has_key?(style, :bg)
      assert Map.has_key?(style, :bold)
      assert Map.has_key?(style, :border)
    end

    test "uses cyan as default color" do
      style = Indicator.default_style()

      assert style.fg == :cyan
    end

    test "has bold enabled by default" do
      style = Indicator.default_style()

      assert style.bold == true
    end
  end

  describe "get_style/2" do
    test "returns default style when no custom" do
      style = Indicator.get_style(:button)

      assert style == Indicator.default_style()
    end

    test "merges custom style with default" do
      custom = %{fg: :yellow}
      opts = [styles: %{button: custom}]

      style = Indicator.get_style(:button, opts)

      assert style.fg == :yellow
      # Other properties from default
      assert style.bold == true
    end

    test "custom style overrides all properties" do
      custom = %{fg: :red, bg: :blue, bold: false, border: :double}
      opts = [styles: %{button: custom}]

      style = Indicator.get_style(:button, opts)

      assert style == custom
    end
  end

  describe "to_render_style/1" do
    test "creates Style struct from indicator" do
      indicator = %{fg: :cyan, bg: nil, bold: true, border: :single}

      result = Indicator.to_render_style(indicator)

      assert %Style{} = result
    end

    test "sets foreground color" do
      indicator = %{fg: :cyan, bg: nil, bold: false, border: nil}

      result = Indicator.to_render_style(indicator)

      assert result.fg == :cyan
    end

    test "sets background color" do
      indicator = %{fg: nil, bg: :blue, bold: false, border: nil}

      result = Indicator.to_render_style(indicator)

      assert result.bg == :blue
    end

    test "sets bold" do
      indicator = %{fg: nil, bg: nil, bold: true, border: nil}

      result = Indicator.to_render_style(indicator)

      assert :bold in result.attrs
    end

    test "handles nil values" do
      indicator = %{fg: nil, bg: nil, bold: false, border: nil}

      result = Indicator.to_render_style(indicator)

      assert %Style{} = result
    end
  end

  describe "focus_border_color/0" do
    test "returns a color atom" do
      color = Indicator.focus_border_color()

      assert is_atom(color)
      assert color == :cyan
    end
  end

  describe "animate?/0" do
    test "returns a boolean" do
      result = Indicator.animate?()

      assert is_boolean(result)
    end
  end

  describe "themes/0" do
    test "returns map of themes" do
      themes = Indicator.themes()

      assert is_map(themes)
      assert Map.has_key?(themes, :default)
      assert Map.has_key?(themes, :subtle)
      assert Map.has_key?(themes, :bold)
      assert Map.has_key?(themes, :minimal)
    end

    test "default theme matches default_style" do
      themes = Indicator.themes()

      assert themes[:default] == Indicator.default_style()
    end

    test "all themes have required keys" do
      themes = Indicator.themes()

      for {_name, theme} <- themes do
        assert Map.has_key?(theme, :fg)
        assert Map.has_key?(theme, :bg)
        assert Map.has_key?(theme, :bold)
        assert Map.has_key?(theme, :border)
      end
    end
  end

  describe "get_theme/1" do
    test "returns theme by name" do
      theme = Indicator.get_theme(:bold)

      assert theme.fg == :yellow
      assert theme.bg == :blue
    end

    test "returns default for unknown theme" do
      theme = Indicator.get_theme(:unknown)

      assert theme == Indicator.default_style()
    end

    test "minimal theme has no styling" do
      theme = Indicator.get_theme(:minimal)

      assert theme.fg == nil
      assert theme.bg == nil
      assert theme.bold == false
      assert theme.border == nil
    end
  end
end
