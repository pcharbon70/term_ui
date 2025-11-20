defmodule TermUI.Renderer.BufferTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.{Buffer, Cell, Style}

  describe "new/2" do
    test "creates buffer with dimensions" do
      {:ok, buffer} = Buffer.new(24, 80)
      assert buffer.rows == 24
      assert buffer.cols == 80
    end

    test "initializes cells to empty" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Buffer.get_cell(buffer, 1, 1)
      assert Cell.empty?(cell)
      Buffer.destroy(buffer)
    end

    test "rejects zero dimensions" do
      assert_raise FunctionClauseError, fn ->
        Buffer.new(0, 80)
      end
    end

    test "rejects negative dimensions" do
      assert_raise FunctionClauseError, fn ->
        Buffer.new(-1, 80)
      end
    end
  end

  describe "destroy/1" do
    test "destroys buffer" do
      {:ok, buffer} = Buffer.new(10, 10)
      assert :ok = Buffer.destroy(buffer)
    end
  end

  describe "get_cell/3" do
    test "returns cell at position" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Cell.new("A", fg: :red)
      Buffer.set_cell(buffer, 5, 5, cell)

      retrieved = Buffer.get_cell(buffer, 5, 5)
      assert retrieved.char == "A"
      assert retrieved.fg == :red
      Buffer.destroy(buffer)
    end

    test "returns empty for out of bounds" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Buffer.get_cell(buffer, 100, 100)
      assert Cell.empty?(cell)
      Buffer.destroy(buffer)
    end

    test "returns empty for unset cell" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Buffer.get_cell(buffer, 1, 1)
      assert Cell.empty?(cell)
      Buffer.destroy(buffer)
    end
  end

  describe "set_cell/4" do
    test "sets cell at position" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Cell.new("X")
      assert :ok = Buffer.set_cell(buffer, 1, 1, cell)
      assert Buffer.get_cell(buffer, 1, 1).char == "X"
      Buffer.destroy(buffer)
    end

    test "returns error for out of bounds" do
      {:ok, buffer} = Buffer.new(10, 10)
      cell = Cell.new("X")
      assert {:error, :out_of_bounds} = Buffer.set_cell(buffer, 100, 100, cell)
      Buffer.destroy(buffer)
    end

    test "overwrites existing cell" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))
      Buffer.set_cell(buffer, 1, 1, Cell.new("B"))
      assert Buffer.get_cell(buffer, 1, 1).char == "B"
      Buffer.destroy(buffer)
    end
  end

  describe "set_cells/2" do
    test "sets multiple cells" do
      {:ok, buffer} = Buffer.new(10, 10)

      cells = [
        {1, 1, Cell.new("A")},
        {1, 2, Cell.new("B")},
        {1, 3, Cell.new("C")}
      ]

      assert :ok = Buffer.set_cells(buffer, cells)
      assert Buffer.get_cell(buffer, 1, 1).char == "A"
      assert Buffer.get_cell(buffer, 1, 2).char == "B"
      assert Buffer.get_cell(buffer, 1, 3).char == "C"
      Buffer.destroy(buffer)
    end

    test "ignores out of bounds cells" do
      {:ok, buffer} = Buffer.new(10, 10)

      cells = [
        {1, 1, Cell.new("A")},
        {100, 100, Cell.new("X")}
      ]

      assert :ok = Buffer.set_cells(buffer, cells)
      assert Buffer.get_cell(buffer, 1, 1).char == "A"
      Buffer.destroy(buffer)
    end
  end

  describe "clear_region/5" do
    test "clears rectangular region" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 2, 2, Cell.new("X"))
      Buffer.set_cell(buffer, 3, 3, Cell.new("Y"))

      Buffer.clear_region(buffer, 2, 2, 3, 3)

      assert Cell.empty?(Buffer.get_cell(buffer, 2, 2))
      assert Cell.empty?(Buffer.get_cell(buffer, 3, 3))
      Buffer.destroy(buffer)
    end

    test "handles region beyond bounds" do
      {:ok, buffer} = Buffer.new(5, 5)
      # Should not raise
      Buffer.clear_region(buffer, 1, 1, 100, 100)
      Buffer.destroy(buffer)
    end
  end

  describe "clear/1" do
    test "clears entire buffer" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))
      Buffer.set_cell(buffer, 10, 10, Cell.new("Z"))

      Buffer.clear(buffer)

      assert Cell.empty?(Buffer.get_cell(buffer, 1, 1))
      assert Cell.empty?(Buffer.get_cell(buffer, 10, 10))
      Buffer.destroy(buffer)
    end
  end

  describe "clear_row/2" do
    test "clears single row" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))
      Buffer.set_cell(buffer, 1, 5, Cell.new("B"))
      Buffer.set_cell(buffer, 2, 1, Cell.new("C"))

      Buffer.clear_row(buffer, 1)

      assert Cell.empty?(Buffer.get_cell(buffer, 1, 1))
      assert Cell.empty?(Buffer.get_cell(buffer, 1, 5))
      assert Buffer.get_cell(buffer, 2, 1).char == "C"
      Buffer.destroy(buffer)
    end
  end

  describe "clear_col/2" do
    test "clears single column" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))
      Buffer.set_cell(buffer, 5, 1, Cell.new("B"))
      Buffer.set_cell(buffer, 1, 2, Cell.new("C"))

      Buffer.clear_col(buffer, 1)

      assert Cell.empty?(Buffer.get_cell(buffer, 1, 1))
      assert Cell.empty?(Buffer.get_cell(buffer, 5, 1))
      assert Buffer.get_cell(buffer, 1, 2).char == "C"
      Buffer.destroy(buffer)
    end
  end

  describe "resize/3" do
    test "grows buffer preserving content" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 5, 5, Cell.new("X"))

      {:ok, new_buffer} = Buffer.resize(buffer, 20, 20)

      assert new_buffer.rows == 20
      assert new_buffer.cols == 20
      assert Buffer.get_cell(new_buffer, 5, 5).char == "X"
      Buffer.destroy(new_buffer)
    end

    test "shrinks buffer clipping content" do
      {:ok, buffer} = Buffer.new(10, 10)
      Buffer.set_cell(buffer, 5, 5, Cell.new("X"))
      Buffer.set_cell(buffer, 8, 8, Cell.new("Y"))

      {:ok, new_buffer} = Buffer.resize(buffer, 6, 6)

      assert new_buffer.rows == 6
      assert new_buffer.cols == 6
      assert Buffer.get_cell(new_buffer, 5, 5).char == "X"
      # Cell at 8,8 was clipped
      Buffer.destroy(new_buffer)
    end

    test "initializes new cells to empty" do
      {:ok, buffer} = Buffer.new(5, 5)
      {:ok, new_buffer} = Buffer.resize(buffer, 10, 10)

      assert Cell.empty?(Buffer.get_cell(new_buffer, 6, 6))
      assert Cell.empty?(Buffer.get_cell(new_buffer, 10, 10))
      Buffer.destroy(new_buffer)
    end
  end

  describe "dimensions/1" do
    test "returns rows and cols" do
      {:ok, buffer} = Buffer.new(24, 80)
      assert Buffer.dimensions(buffer) == {24, 80}
      Buffer.destroy(buffer)
    end
  end

  describe "in_bounds?/3" do
    test "returns true for valid position" do
      {:ok, buffer} = Buffer.new(10, 10)
      assert Buffer.in_bounds?(buffer, 1, 1)
      assert Buffer.in_bounds?(buffer, 10, 10)
      assert Buffer.in_bounds?(buffer, 5, 5)
      Buffer.destroy(buffer)
    end

    test "returns false for out of bounds" do
      {:ok, buffer} = Buffer.new(10, 10)
      refute Buffer.in_bounds?(buffer, 0, 1)
      refute Buffer.in_bounds?(buffer, 1, 0)
      refute Buffer.in_bounds?(buffer, 11, 1)
      refute Buffer.in_bounds?(buffer, 1, 11)
      Buffer.destroy(buffer)
    end
  end

  describe "each/2" do
    test "iterates over all cells" do
      {:ok, buffer} = Buffer.new(2, 2)
      count = :counters.new(1, [:atomics])

      Buffer.each(buffer, fn {_row, _col, _cell} ->
        :counters.add(count, 1, 1)
      end)

      assert :counters.get(count, 1) == 4
      Buffer.destroy(buffer)
    end
  end

  describe "to_list/1" do
    test "returns all cells as list" do
      {:ok, buffer} = Buffer.new(2, 2)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))

      list = Buffer.to_list(buffer)
      assert length(list) == 4

      {1, 1, cell} = Enum.find(list, fn {r, c, _} -> r == 1 and c == 1 end)
      assert cell.char == "A"
      Buffer.destroy(buffer)
    end
  end

  describe "get_row/2" do
    test "returns all cells in row" do
      {:ok, buffer} = Buffer.new(10, 5)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A"))
      Buffer.set_cell(buffer, 1, 3, Cell.new("B"))

      row = Buffer.get_row(buffer, 1)
      assert length(row) == 5
      assert Enum.at(row, 0).char == "A"
      assert Enum.at(row, 2).char == "B"
      Buffer.destroy(buffer)
    end
  end

  describe "write_string/4" do
    test "writes string to buffer" do
      {:ok, buffer} = Buffer.new(10, 80)
      written = Buffer.write_string(buffer, 1, 1, "Hello")

      assert written == 5
      assert Buffer.get_cell(buffer, 1, 1).char == "H"
      assert Buffer.get_cell(buffer, 1, 2).char == "e"
      assert Buffer.get_cell(buffer, 1, 3).char == "l"
      assert Buffer.get_cell(buffer, 1, 4).char == "l"
      assert Buffer.get_cell(buffer, 1, 5).char == "o"
      Buffer.destroy(buffer)
    end

    test "writes string with style" do
      {:ok, buffer} = Buffer.new(10, 80)
      style = Style.new() |> Style.fg(:red) |> Style.bold()
      Buffer.write_string(buffer, 1, 1, "Hi", style: style)

      cell = Buffer.get_cell(buffer, 1, 1)
      assert cell.char == "H"
      assert cell.fg == :red
      assert :bold in cell.attrs
      Buffer.destroy(buffer)
    end

    test "truncates at buffer edge" do
      {:ok, buffer} = Buffer.new(1, 5)
      written = Buffer.write_string(buffer, 1, 1, "Hello World")

      assert written == 5
      Buffer.destroy(buffer)
    end
  end

  describe "concurrent access" do
    test "handles concurrent writes" do
      {:ok, buffer} = Buffer.new(100, 100)

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            for j <- 1..10 do
              Buffer.set_cell(buffer, i, j, Cell.new("#{i}"))
            end
          end)
        end

      Task.await_many(tasks)

      # Verify all writes completed
      for i <- 1..10, j <- 1..10 do
        cell = Buffer.get_cell(buffer, i, j)
        assert cell.char == "#{i}"
      end

      Buffer.destroy(buffer)
    end
  end
end
