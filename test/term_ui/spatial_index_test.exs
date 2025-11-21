defmodule TermUI.SpatialIndexTest do
  use ExUnit.Case

  alias TermUI.SpatialIndex

  setup do
    # Start spatial index for each test
    start_supervised!(SpatialIndex)
    :ok
  end

  describe "update/4 and find_at/2" do
    test "registers component and finds at position" do
      pid = self()
      bounds = %{x: 10, y: 5, width: 20, height: 3}

      :ok = SpatialIndex.update(:button, pid, bounds)

      # Position inside bounds
      assert {:ok, {:button, ^pid}} = SpatialIndex.find_at(15, 6)
    end

    test "returns not_found when no component at position" do
      assert {:error, :not_found} = SpatialIndex.find_at(100, 100)
    end

    test "finds component at edge of bounds" do
      pid = self()
      bounds = %{x: 0, y: 0, width: 10, height: 5}

      :ok = SpatialIndex.update(:panel, pid, bounds)

      # Top-left corner
      assert {:ok, {:panel, ^pid}} = SpatialIndex.find_at(0, 0)

      # Bottom-right corner (exclusive)
      assert {:error, :not_found} = SpatialIndex.find_at(10, 5)

      # Just inside
      assert {:ok, {:panel, ^pid}} = SpatialIndex.find_at(9, 4)
    end

    test "position outside bounds returns not_found" do
      pid = self()
      bounds = %{x: 10, y: 10, width: 5, height: 5}

      :ok = SpatialIndex.update(:box, pid, bounds)

      # Before bounds
      assert {:error, :not_found} = SpatialIndex.find_at(9, 10)
      assert {:error, :not_found} = SpatialIndex.find_at(10, 9)

      # After bounds
      assert {:error, :not_found} = SpatialIndex.find_at(15, 10)
      assert {:error, :not_found} = SpatialIndex.find_at(10, 15)
    end

    test "updates existing component bounds" do
      pid = self()
      old_bounds = %{x: 0, y: 0, width: 10, height: 10}
      new_bounds = %{x: 20, y: 20, width: 10, height: 10}

      :ok = SpatialIndex.update(:moving, pid, old_bounds)
      assert {:ok, {:moving, ^pid}} = SpatialIndex.find_at(5, 5)

      :ok = SpatialIndex.update(:moving, pid, new_bounds)
      assert {:error, :not_found} = SpatialIndex.find_at(5, 5)
      assert {:ok, {:moving, ^pid}} = SpatialIndex.find_at(25, 25)
    end
  end

  describe "z-order handling" do
    test "returns highest z-index component when overlapping" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)

      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:background, pid1, bounds, z_index: 0)
      :ok = SpatialIndex.update(:modal, pid2, bounds, z_index: 100)

      # Modal (higher z-index) should be returned
      assert {:ok, {:modal, ^pid2}} = SpatialIndex.find_at(5, 5)
    end

    test "default z-index is 0" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)

      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:first, pid1, bounds)
      :ok = SpatialIndex.update(:second, pid2, bounds, z_index: 1)

      # Second should win with z_index: 1 vs default 0
      assert {:ok, {:second, ^pid2}} = SpatialIndex.find_at(5, 5)
    end

    test "same z-index returns one of the components" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)

      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:a, pid1, bounds, z_index: 0)
      :ok = SpatialIndex.update(:b, pid2, bounds, z_index: 0)

      # Either component is acceptable
      {:ok, {id, _pid}} = SpatialIndex.find_at(5, 5)
      assert id in [:a, :b]
    end
  end

  describe "find_all_at/2" do
    test "returns all components at position sorted by z-index" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)
      pid3 = spawn(fn -> Process.sleep(:infinity) end)

      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:bottom, pid1, bounds, z_index: 0)
      :ok = SpatialIndex.update(:middle, pid2, bounds, z_index: 50)
      :ok = SpatialIndex.update(:top, pid3, bounds, z_index: 100)

      result = SpatialIndex.find_all_at(5, 5)

      assert length(result) == 3
      assert [{:top, ^pid3, 100}, {:middle, ^pid2, 50}, {:bottom, ^pid1, 0}] = result
    end

    test "returns empty list when no component at position" do
      assert [] = SpatialIndex.find_all_at(100, 100)
    end
  end

  describe "remove/1" do
    test "removes component from index" do
      pid = self()
      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:temp, pid, bounds)
      assert {:ok, {:temp, ^pid}} = SpatialIndex.find_at(5, 5)

      :ok = SpatialIndex.remove(:temp)
      assert {:error, :not_found} = SpatialIndex.find_at(5, 5)
    end

    test "remove non-existent component succeeds" do
      :ok = SpatialIndex.remove(:nonexistent)
    end
  end

  describe "get_bounds/1" do
    test "returns bounds for registered component" do
      pid = self()
      bounds = %{x: 10, y: 20, width: 30, height: 40}

      :ok = SpatialIndex.update(:panel, pid, bounds)

      assert {:ok, ^bounds} = SpatialIndex.get_bounds(:panel)
    end

    test "returns not_found for unregistered component" do
      assert {:error, :not_found} = SpatialIndex.get_bounds(:unknown)
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      pid = self()
      bounds = %{x: 0, y: 0, width: 10, height: 10}

      :ok = SpatialIndex.update(:a, pid, bounds)
      :ok = SpatialIndex.update(:b, pid, bounds)

      assert SpatialIndex.count() == 2

      :ok = SpatialIndex.clear()

      assert SpatialIndex.count() == 0
      assert {:error, :not_found} = SpatialIndex.find_at(5, 5)
    end
  end

  describe "count/0" do
    test "returns number of indexed components" do
      assert SpatialIndex.count() == 0

      pid = self()
      :ok = SpatialIndex.update(:a, pid, %{x: 0, y: 0, width: 1, height: 1})
      assert SpatialIndex.count() == 1

      :ok = SpatialIndex.update(:b, pid, %{x: 1, y: 1, width: 1, height: 1})
      assert SpatialIndex.count() == 2
    end
  end
end
