defmodule TermUI.Layout.ConstraintTest do
  use ExUnit.Case, async: true

  alias TermUI.Layout.Constraint
  alias TermUI.Layout.Constraint.{Length, Percentage, Ratio, Min, Max, Fill}

  describe "length/1" do
    test "creates length constraint with exact size" do
      constraint = Constraint.length(20)
      assert %Length{value: 20} = constraint
    end

    test "accepts zero" do
      constraint = Constraint.length(0)
      assert %Length{value: 0} = constraint
    end

    test "raises for negative values" do
      assert_raise ArgumentError, ~r/must be non-negative/, fn ->
        Constraint.length(-1)
      end
    end

    test "raises for non-integer values" do
      assert_raise ArgumentError, ~r/must be a non-negative integer/, fn ->
        Constraint.length(20.5)
      end
    end
  end

  describe "percentage/1" do
    test "creates percentage constraint" do
      constraint = Constraint.percentage(50)
      assert %Percentage{value: 50} = constraint
    end

    test "accepts float values" do
      constraint = Constraint.percentage(33.33)
      assert %Percentage{value: 33.33} = constraint
    end

    test "accepts zero" do
      constraint = Constraint.percentage(0)
      assert %Percentage{value: 0} = constraint
    end

    test "accepts 100" do
      constraint = Constraint.percentage(100)
      assert %Percentage{value: 100} = constraint
    end

    test "raises for values over 100" do
      assert_raise ArgumentError, ~r/must be between 0 and 100/, fn ->
        Constraint.percentage(101)
      end
    end

    test "raises for negative values" do
      assert_raise ArgumentError, ~r/must be between 0 and 100/, fn ->
        Constraint.percentage(-1)
      end
    end

    test "raises for non-numeric values" do
      assert_raise ArgumentError, ~r/must be a number/, fn ->
        Constraint.percentage("50")
      end
    end
  end

  describe "ratio/1" do
    test "creates ratio constraint" do
      constraint = Constraint.ratio(2)
      assert %Ratio{value: 2} = constraint
    end

    test "accepts float values" do
      constraint = Constraint.ratio(1.5)
      assert %Ratio{value: 1.5} = constraint
    end

    test "raises for zero" do
      assert_raise ArgumentError, ~r/must be positive/, fn ->
        Constraint.ratio(0)
      end
    end

    test "raises for negative values" do
      assert_raise ArgumentError, ~r/must be positive/, fn ->
        Constraint.ratio(-1)
      end
    end

    test "raises for non-numeric values" do
      assert_raise ArgumentError, ~r/must be a positive number/, fn ->
        Constraint.ratio("1")
      end
    end
  end

  describe "min/1" do
    test "creates min constraint with fill default" do
      constraint = Constraint.min(10)
      assert %Min{value: 10, constraint: %Fill{}} = constraint
    end

    test "accepts zero" do
      constraint = Constraint.min(0)
      assert %Min{value: 0, constraint: %Fill{}} = constraint
    end

    test "raises for negative values" do
      assert_raise ArgumentError, ~r/must be non-negative/, fn ->
        Constraint.min(-1)
      end
    end

    test "raises for non-integer values" do
      assert_raise ArgumentError, ~r/must be a non-negative integer/, fn ->
        Constraint.min(10.5)
      end
    end
  end

  describe "max/1" do
    test "creates max constraint with fill default" do
      constraint = Constraint.max(100)
      assert %Max{value: 100, constraint: %Fill{}} = constraint
    end

    test "accepts zero" do
      constraint = Constraint.max(0)
      assert %Max{value: 0, constraint: %Fill{}} = constraint
    end

    test "raises for negative values" do
      assert_raise ArgumentError, ~r/must be non-negative/, fn ->
        Constraint.max(-1)
      end
    end

    test "raises for non-integer values" do
      assert_raise ArgumentError, ~r/must be a non-negative integer/, fn ->
        Constraint.max(100.5)
      end
    end
  end

  describe "min_max/2" do
    test "creates combined min/max constraint" do
      constraint = Constraint.min_max(10, 100)
      assert %Min{value: 10, constraint: %Max{value: 100, constraint: %Fill{}}} = constraint
    end

    test "accepts equal min and max" do
      constraint = Constraint.min_max(50, 50)
      assert %Min{value: 50, constraint: %Max{value: 50, constraint: %Fill{}}} = constraint
    end

    test "raises when min > max" do
      assert_raise ArgumentError, ~r/cannot be greater than max/, fn ->
        Constraint.min_max(100, 10)
      end
    end

    test "raises for invalid values" do
      assert_raise ArgumentError, ~r/requires non-negative integers/, fn ->
        Constraint.min_max(-1, 100)
      end
    end
  end

  describe "fill/0" do
    test "creates fill constraint" do
      constraint = Constraint.fill()
      assert %Fill{} = constraint
    end
  end

  describe "with_min/2" do
    test "adds min bound to constraint" do
      constraint = Constraint.percentage(50) |> Constraint.with_min(10)
      assert %Min{value: 10, constraint: %Percentage{value: 50}} = constraint
    end

    test "can be chained" do
      constraint =
        Constraint.percentage(50)
        |> Constraint.with_min(10)
        |> Constraint.with_max(100)

      assert %Max{value: 100, constraint: %Min{value: 10, constraint: %Percentage{value: 50}}} =
               constraint
    end

    test "raises for non-integer values" do
      assert_raise ArgumentError, ~r/requires non-negative integer/, fn ->
        Constraint.percentage(50) |> Constraint.with_min(10.5)
      end
    end
  end

  describe "with_max/2" do
    test "adds max bound to constraint" do
      constraint = Constraint.percentage(50) |> Constraint.with_max(100)
      assert %Max{value: 100, constraint: %Percentage{value: 50}} = constraint
    end

    test "raises for non-integer values" do
      assert_raise ArgumentError, ~r/requires non-negative integer/, fn ->
        Constraint.percentage(50) |> Constraint.with_max(100.5)
      end
    end
  end

  describe "resolve/3 - length" do
    test "returns exact requested size" do
      constraint = Constraint.length(20)
      assert 20 = Constraint.resolve(constraint, 100)
    end

    test "truncates when exceeding available space" do
      constraint = Constraint.length(150)
      assert 100 = Constraint.resolve(constraint, 100)
    end

    test "returns zero for zero length" do
      constraint = Constraint.length(0)
      assert 0 = Constraint.resolve(constraint, 100)
    end
  end

  describe "resolve/3 - percentage" do
    test "calculates correct fraction of parent" do
      constraint = Constraint.percentage(50)
      assert 50 = Constraint.resolve(constraint, 100)
    end

    test "rounds to nearest integer" do
      constraint = Constraint.percentage(33.33)
      assert 33 = Constraint.resolve(constraint, 100)
    end

    test "handles zero percentage" do
      constraint = Constraint.percentage(0)
      assert 0 = Constraint.resolve(constraint, 100)
    end

    test "handles 100 percentage" do
      constraint = Constraint.percentage(100)
      assert 100 = Constraint.resolve(constraint, 100)
    end

    test "works with small available space" do
      constraint = Constraint.percentage(50)
      assert 5 = Constraint.resolve(constraint, 10)
    end
  end

  describe "resolve/3 - ratio" do
    test "distributes space proportionally" do
      constraint = Constraint.ratio(2)
      result = Constraint.resolve(constraint, 100, remaining: 60, total_ratio: 3)
      assert 40 = result
    end

    test "handles single ratio taking all remaining" do
      constraint = Constraint.ratio(1)
      result = Constraint.resolve(constraint, 100, remaining: 30, total_ratio: 1)
      assert 30 = result
    end

    test "returns zero when no remaining space" do
      constraint = Constraint.ratio(2)
      result = Constraint.resolve(constraint, 100, remaining: 0, total_ratio: 3)
      assert 0 = result
    end

    test "returns zero when total_ratio is zero" do
      constraint = Constraint.ratio(2)
      result = Constraint.resolve(constraint, 100, remaining: 60, total_ratio: 0)
      assert 0 = result
    end
  end

  describe "resolve/3 - fill" do
    test "uses all remaining space" do
      constraint = Constraint.fill()
      result = Constraint.resolve(constraint, 100, remaining: 30)
      assert 30 = result
    end

    test "returns zero when no remaining space" do
      constraint = Constraint.fill()
      result = Constraint.resolve(constraint, 100, remaining: 0)
      assert 0 = result
    end

    test "defaults to zero without remaining option" do
      constraint = Constraint.fill()
      result = Constraint.resolve(constraint, 100)
      assert 0 = result
    end
  end

  describe "resolve/3 - min" do
    test "enforces minimum size" do
      constraint = Constraint.percentage(10) |> Constraint.with_min(20)
      result = Constraint.resolve(constraint, 100)
      # percentage gives 10, min enforces 20
      assert 20 = result
    end

    test "does not affect when inner exceeds min" do
      constraint = Constraint.percentage(50) |> Constraint.with_min(20)
      result = Constraint.resolve(constraint, 100)
      # percentage gives 50, which exceeds min 20
      assert 50 = result
    end

    test "works with fill" do
      constraint = Constraint.min(10)
      result = Constraint.resolve(constraint, 100, remaining: 5)
      # fill gives 5, min enforces 10
      assert 10 = result
    end
  end

  describe "resolve/3 - max" do
    test "enforces maximum size" do
      constraint = Constraint.percentage(80) |> Constraint.with_max(50)
      result = Constraint.resolve(constraint, 100)
      # percentage gives 80, max enforces 50
      assert 50 = result
    end

    test "does not affect when inner is below max" do
      constraint = Constraint.percentage(30) |> Constraint.with_max(50)
      result = Constraint.resolve(constraint, 100)
      # percentage gives 30, which is below max 50
      assert 30 = result
    end

    test "works with fill" do
      constraint = Constraint.max(50)
      result = Constraint.resolve(constraint, 100, remaining: 80)
      # fill gives 80, max enforces 50
      assert 50 = result
    end
  end

  describe "resolve/3 - combined bounds" do
    test "applies both min and max" do
      constraint =
        Constraint.percentage(5)
        |> Constraint.with_min(10)
        |> Constraint.with_max(50)

      result = Constraint.resolve(constraint, 100)
      # percentage gives 5, min enforces 10, max allows up to 50
      assert 10 = result
    end

    test "max takes precedence when inner exceeds both" do
      constraint =
        Constraint.percentage(80)
        |> Constraint.with_min(10)
        |> Constraint.with_max(50)

      result = Constraint.resolve(constraint, 100)
      # percentage gives 80, max enforces 50
      assert 50 = result
    end

    test "min_max works correctly" do
      constraint = Constraint.min_max(10, 50)

      # Below min
      result1 = Constraint.resolve(constraint, 100, remaining: 5)
      assert 10 = result1

      # Above max
      result2 = Constraint.resolve(constraint, 100, remaining: 80)
      assert 50 = result2

      # Within bounds
      result3 = Constraint.resolve(constraint, 100, remaining: 30)
      assert 30 = result3
    end
  end

  describe "type/1" do
    test "returns :length for length constraint" do
      assert :length = Constraint.type(Constraint.length(20))
    end

    test "returns :percentage for percentage constraint" do
      assert :percentage = Constraint.type(Constraint.percentage(50))
    end

    test "returns :ratio for ratio constraint" do
      assert :ratio = Constraint.type(Constraint.ratio(2))
    end

    test "returns :fill for fill constraint" do
      assert :fill = Constraint.type(Constraint.fill())
    end

    test "returns tuple for bounded constraints" do
      assert {:min, :percentage} =
               Constraint.type(Constraint.percentage(50) |> Constraint.with_min(10))

      assert {:max, :fill} = Constraint.type(Constraint.max(100))
    end
  end

  describe "fixed?/1" do
    test "returns true for length constraint" do
      assert Constraint.fixed?(Constraint.length(20))
    end

    test "returns true for bounded length" do
      assert Constraint.fixed?(Constraint.length(20) |> Constraint.with_min(10))
      assert Constraint.fixed?(Constraint.length(20) |> Constraint.with_max(30))
    end

    test "returns false for percentage" do
      refute Constraint.fixed?(Constraint.percentage(50))
    end

    test "returns false for ratio" do
      refute Constraint.fixed?(Constraint.ratio(2))
    end

    test "returns false for fill" do
      refute Constraint.fixed?(Constraint.fill())
    end
  end

  describe "flexible?/1" do
    test "returns true for ratio constraint" do
      assert Constraint.flexible?(Constraint.ratio(2))
    end

    test "returns true for fill constraint" do
      assert Constraint.flexible?(Constraint.fill())
    end

    test "returns true for bounded flexible" do
      assert Constraint.flexible?(Constraint.ratio(2) |> Constraint.with_min(10))
      assert Constraint.flexible?(Constraint.fill() |> Constraint.with_max(100))
    end

    test "returns false for length" do
      refute Constraint.flexible?(Constraint.length(20))
    end

    test "returns false for percentage" do
      refute Constraint.flexible?(Constraint.percentage(50))
    end
  end

  describe "get_min/1" do
    test "returns min value from min constraint" do
      assert 10 = Constraint.get_min(Constraint.min(10))
      assert 20 = Constraint.get_min(Constraint.percentage(50) |> Constraint.with_min(20))
    end

    test "returns nil for non-min constraints" do
      assert nil == Constraint.get_min(Constraint.length(20))
      assert nil == Constraint.get_min(Constraint.percentage(50))
    end
  end

  describe "get_max/1" do
    test "returns max value from max constraint" do
      assert 100 = Constraint.get_max(Constraint.max(100))
      assert 50 = Constraint.get_max(Constraint.percentage(50) |> Constraint.with_max(50))
    end

    test "returns max from nested min/max" do
      assert 100 = Constraint.get_max(Constraint.min_max(10, 100))
    end

    test "returns nil for non-max constraints" do
      assert nil == Constraint.get_max(Constraint.length(20))
      assert nil == Constraint.get_max(Constraint.min(10))
    end
  end

  describe "unwrap/1" do
    test "unwraps min constraint" do
      constraint = Constraint.percentage(50) |> Constraint.with_min(10)
      assert %Percentage{value: 50} = Constraint.unwrap(constraint)
    end

    test "unwraps max constraint" do
      constraint = Constraint.ratio(2) |> Constraint.with_max(100)
      assert %Ratio{value: 2} = Constraint.unwrap(constraint)
    end

    test "unwraps nested bounds" do
      constraint =
        Constraint.fill()
        |> Constraint.with_min(10)
        |> Constraint.with_max(100)

      assert %Fill{} = Constraint.unwrap(constraint)
    end

    test "returns base constraints unchanged" do
      assert %Length{value: 20} = Constraint.unwrap(Constraint.length(20))
      assert %Percentage{value: 50} = Constraint.unwrap(Constraint.percentage(50))
      assert %Fill{} = Constraint.unwrap(Constraint.fill())
    end
  end
end
