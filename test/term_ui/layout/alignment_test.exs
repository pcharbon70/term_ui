defmodule TermUI.Layout.AlignmentTest do
  use ExUnit.Case, async: true

  alias TermUI.Layout.Alignment

  # Helper to create test rects
  defp make_rects(sizes, direction \\ :horizontal) do
    {rects, _pos} =
      Enum.map_reduce(sizes, 0, fn size, pos ->
        rect =
          case direction do
            :horizontal -> %{x: pos, y: 0, width: size, height: 10}
            :vertical -> %{x: 0, y: pos, width: 10, height: size}
          end

        {rect, pos + size}
      end)

    rects
  end

  describe "apply/3 - justify :start" do
    test "positions at beginning (default)" do
      rects = make_rects([20, 30])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area)

      assert [
               %{x: 0, width: 20},
               %{x: 20, width: 30}
             ] = result
    end

    test "positions at area offset" do
      rects = make_rects([20, 30])
      area = %{x: 10, y: 5, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :start)

      assert [
               %{x: 10, width: 20},
               %{x: 30, width: 30}
             ] = result
    end
  end

  describe "apply/3 - justify :center" do
    test "centers components in available space" do
      rects = make_rects([20, 30])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :center)

      # Total content = 50, space = 50, offset = 25
      assert [
               %{x: 25, width: 20},
               %{x: 45, width: 30}
             ] = result
    end

    test "centers with area offset" do
      rects = make_rects([20])
      area = %{x: 10, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :center)

      # Content = 20, space = 80, offset = 40
      assert [%{x: 50, width: 20}] = result
    end
  end

  describe "apply/3 - justify :end" do
    test "positions at end of available space" do
      rects = make_rects([20, 30])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :end)

      # Total content = 50, offset = 50
      assert [
               %{x: 50, width: 20},
               %{x: 70, width: 30}
             ] = result
    end

    test "positions at end with area offset" do
      rects = make_rects([20])
      area = %{x: 10, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :end)

      # Content = 20, offset = 80
      assert [%{x: 90, width: 20}] = result
    end
  end

  describe "apply/3 - justify :space_between" do
    test "distributes space between components" do
      rects = make_rects([20, 20, 20])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :space_between)

      # Total content = 60, space = 40, between = 20
      assert [
               %{x: 0, width: 20},
               %{x: 40, width: 20},
               %{x: 80, width: 20}
             ] = result
    end

    test "handles single component" do
      rects = make_rects([20])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :space_between)

      # Single component stays at start
      assert [%{x: 0, width: 20}] = result
    end

    test "handles two components" do
      rects = make_rects([20, 20])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :space_between)

      # Space = 60, between = 60
      assert [
               %{x: 0, width: 20},
               %{x: 80, width: 20}
             ] = result
    end
  end

  describe "apply/3 - justify :space_around" do
    test "distributes space around components" do
      rects = make_rects([20, 20])
      area = %{x: 0, y: 0, width: 100, height: 20}

      result = Alignment.apply(rects, area, justify: :space_around)

      # Total content = 40, space = 60, unit = 15
      # First at 15, second at 15 + 20 + 30 = 65
      assert [
               %{x: 15, width: 20},
               %{x: 65, width: 20}
             ] = result
    end

    test "handles empty list" do
      result = Alignment.apply([], %{x: 0, y: 0, width: 100, height: 20}, justify: :space_around)
      assert [] = result
    end
  end

  describe "apply/3 - align :start" do
    test "positions at cross-axis start (default)" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :start)

      assert [%{y: 0, height: 10}] = result
    end
  end

  describe "apply/3 - align :center" do
    test "centers on cross-axis" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :center)

      # Height = 10, space = 40, offset = 20
      assert [%{y: 20, height: 10}] = result
    end

    test "centers multiple components" do
      rects = [
        %{x: 0, y: 0, width: 20, height: 10},
        %{x: 20, y: 0, width: 30, height: 20}
      ]

      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :center)

      # Each centered independently
      assert [
               # (50 - 10) / 2 = 20
               %{y: 20, height: 10},
               # (50 - 20) / 2 = 15
               %{y: 15, height: 20}
             ] = result
    end
  end

  describe "apply/3 - align :end" do
    test "positions at cross-axis end" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :end)

      # Height = 10, offset = 40
      assert [%{y: 40, height: 10}] = result
    end
  end

  describe "apply/3 - align :stretch" do
    test "expands to fill cross-axis" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :stretch)

      assert [%{y: 0, height: 50}] = result
    end

    test "stretches multiple components" do
      rects = [
        %{x: 0, y: 0, width: 20, height: 10},
        %{x: 20, y: 0, width: 30, height: 20}
      ]

      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, align: :stretch)

      assert [
               %{y: 0, height: 50},
               %{y: 0, height: 50}
             ] = result
    end
  end

  describe "apply/3 - align_self" do
    test "overrides container alignment per component" do
      rects = [
        %{x: 0, y: 0, width: 20, height: 10},
        %{x: 20, y: 0, width: 30, height: 10},
        %{x: 50, y: 0, width: 20, height: 10}
      ]

      area = %{x: 0, y: 0, width: 100, height: 50}

      result =
        Alignment.apply(rects, area,
          align: :start,
          align_self: [:center, nil, :end]
        )

      assert [
               # center
               %{y: 20, height: 10},
               # start (nil = use container)
               %{y: 0, height: 10},
               # end
               %{y: 40, height: 10}
             ] = result
    end
  end

  describe "apply/3 - vertical direction" do
    test "justify centers vertically" do
      rects = [
        %{x: 0, y: 0, width: 10, height: 20},
        %{x: 0, y: 20, width: 10, height: 30}
      ]

      area = %{x: 0, y: 0, width: 50, height: 100}

      result = Alignment.apply(rects, area, direction: :vertical, justify: :center)

      # Total content = 50, space = 50, offset = 25
      assert [
               %{y: 25, height: 20},
               %{y: 45, height: 30}
             ] = result
    end

    test "align centers horizontally in vertical layout" do
      rects = [%{x: 0, y: 0, width: 10, height: 20}]
      area = %{x: 0, y: 0, width: 50, height: 100}

      result = Alignment.apply(rects, area, direction: :vertical, align: :center)

      # Width = 10, space = 40, offset = 20
      assert [%{x: 20, width: 10}] = result
    end

    test "stretch expands width in vertical layout" do
      rects = [%{x: 0, y: 0, width: 10, height: 20}]
      area = %{x: 0, y: 0, width: 50, height: 100}

      result = Alignment.apply(rects, area, direction: :vertical, align: :stretch)

      assert [%{x: 0, width: 50}] = result
    end
  end

  describe "apply_margins/2" do
    test "applies uniform margin to all rects" do
      rects = [
        %{x: 0, y: 0, width: 100, height: 50},
        %{x: 100, y: 0, width: 100, height: 50}
      ]

      margin = %{top: 5, right: 5, bottom: 5, left: 5}

      result = Alignment.apply_margins(rects, margin)

      assert [
               %{x: 5, y: 5, width: 90, height: 40},
               %{x: 105, y: 5, width: 90, height: 40}
             ] = result
    end

    test "applies per-rect margins" do
      rects = [
        %{x: 0, y: 0, width: 100, height: 50},
        %{x: 100, y: 0, width: 100, height: 50}
      ]

      margins = [
        %{top: 5, right: 5, bottom: 5, left: 5},
        %{top: 10, right: 10, bottom: 10, left: 10}
      ]

      result = Alignment.apply_margins(rects, margins)

      assert [
               %{x: 5, y: 5, width: 90, height: 40},
               %{x: 110, y: 10, width: 80, height: 30}
             ] = result
    end

    test "handles zero margin" do
      rects = [%{x: 0, y: 0, width: 100, height: 50}]
      margin = %{top: 0, right: 0, bottom: 0, left: 0}

      result = Alignment.apply_margins(rects, margin)

      assert [%{x: 0, y: 0, width: 100, height: 50}] = result
    end
  end

  describe "apply_padding/2" do
    test "reduces content area" do
      rect = %{x: 10, y: 20, width: 100, height: 50}
      padding = %{top: 5, right: 10, bottom: 5, left: 10}

      result = Alignment.apply_padding(rect, padding)

      assert %{x: 20, y: 25, width: 80, height: 40} = result
    end

    test "handles zero padding" do
      rect = %{x: 10, y: 20, width: 100, height: 50}
      padding = %{top: 0, right: 0, bottom: 0, left: 0}

      result = Alignment.apply_padding(rect, padding)

      assert %{x: 10, y: 20, width: 100, height: 50} = result
    end

    test "clamps to zero for excessive padding" do
      rect = %{x: 0, y: 0, width: 20, height: 20}
      padding = %{top: 15, right: 15, bottom: 15, left: 15}

      result = Alignment.apply_padding(rect, padding)

      assert result.width == 0
      assert result.height == 0
    end
  end

  describe "parse_spacing/1" do
    test "parses single value" do
      result = Alignment.parse_spacing(10)
      assert %{top: 10, right: 10, bottom: 10, left: 10} = result
    end

    test "parses vertical/horizontal tuple" do
      result = Alignment.parse_spacing({5, 10})
      assert %{top: 5, right: 10, bottom: 5, left: 10} = result
    end

    test "parses four-value tuple" do
      result = Alignment.parse_spacing({1, 2, 3, 4})
      assert %{top: 1, right: 2, bottom: 3, left: 4} = result
    end

    test "parses map with defaults" do
      result = Alignment.parse_spacing(%{top: 5, left: 10})
      assert %{top: 5, right: 0, bottom: 0, left: 10} = result
    end
  end

  describe "combined justify and align" do
    test "applies both simultaneously" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, justify: :center, align: :center)

      # Centered both ways
      assert [%{x: 40, y: 20, width: 20, height: 10}] = result
    end

    test "end/end positions in bottom-right" do
      rects = [%{x: 0, y: 0, width: 20, height: 10}]
      area = %{x: 0, y: 0, width: 100, height: 50}

      result = Alignment.apply(rects, area, justify: :end, align: :end)

      assert [%{x: 80, y: 40, width: 20, height: 10}] = result
    end
  end
end
