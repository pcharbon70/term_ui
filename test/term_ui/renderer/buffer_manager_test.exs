defmodule TermUI.Renderer.BufferManagerTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.BufferManager
  alias TermUI.Renderer.Cell

  describe "start_link/1" do
    test "creates manager with specified dimensions" do
      {:ok, pid} = BufferManager.start_link(rows: 10, cols: 20, name: :test_manager_1)
      assert is_pid(pid)
      assert Process.alive?(pid)

      assert {10, 20} = BufferManager.dimensions(:test_manager_1)

      GenServer.stop(pid)
    end

    test "requires rows and cols options" do
      Process.flag(:trap_exit, true)

      assert {:error, _} = BufferManager.start_link(rows: 10, name: :test_missing_cols)
      assert {:error, _} = BufferManager.start_link(cols: 20, name: :test_missing_rows)

      Process.flag(:trap_exit, false)
    end
  end

  describe "get_current_buffer/1" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 5, cols: 10, name: :test_current)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_current}
    end

    test "returns valid buffer", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)
      assert %Buffer{} = buffer
      assert {5, 10} = Buffer.dimensions(buffer)
    end

    test "buffer is writable", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)
      cell = Cell.new("X", fg: :red)
      assert :ok = Buffer.set_cell(buffer, 1, 1, cell)

      retrieved = Buffer.get_cell(buffer, 1, 1)
      assert retrieved.char == "X"
      assert retrieved.fg == :red
    end
  end

  describe "get_previous_buffer/1" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 5, cols: 10, name: :test_previous)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_previous}
    end

    test "returns valid buffer", %{server: server} do
      buffer = BufferManager.get_previous_buffer(server)
      assert %Buffer{} = buffer
      assert {5, 10} = Buffer.dimensions(buffer)
    end

    test "previous buffer is different from current", %{server: server} do
      current = BufferManager.get_current_buffer(server)
      previous = BufferManager.get_previous_buffer(server)

      # Different ETS tables
      refute current.table == previous.table
    end
  end

  describe "swap_buffers/1" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 5, cols: 10, name: :test_swap)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_swap}
    end

    test "exchanges current and previous buffers", %{server: server} do
      current_before = BufferManager.get_current_buffer(server)
      previous_before = BufferManager.get_previous_buffer(server)

      # Write to current
      cell = Cell.new("A")
      Buffer.set_cell(current_before, 1, 1, cell)

      # Swap
      assert :ok = BufferManager.swap_buffers(server)

      current_after = BufferManager.get_current_buffer(server)
      previous_after = BufferManager.get_previous_buffer(server)

      # Current should now be what was previous
      assert current_after.table == previous_before.table
      # Previous should now be what was current (with our "A")
      assert previous_after.table == current_before.table

      # Verify content moved
      assert Buffer.get_cell(previous_after, 1, 1).char == "A"
      assert Buffer.get_cell(current_after, 1, 1).char == " "
    end

    test "swap is reversible", %{server: server} do
      current_original = BufferManager.get_current_buffer(server)

      BufferManager.swap_buffers(server)
      BufferManager.swap_buffers(server)

      current_after = BufferManager.get_current_buffer(server)
      assert current_after.table == current_original.table
    end
  end

  describe "dimensions/1" do
    test "returns buffer dimensions" do
      {:ok, pid} = BufferManager.start_link(rows: 24, cols: 80, name: :test_dims)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      assert {24, 80} = BufferManager.dimensions(:test_dims)
    end
  end

  describe "resize/3" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 10, cols: 10, name: :test_resize)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_resize}
    end

    test "updates dimensions", %{server: server} do
      assert :ok = BufferManager.resize(server, 20, 30)
      assert {20, 30} = BufferManager.dimensions(server)
    end

    test "preserves content within new dimensions", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)
      cell = Cell.new("X", fg: :blue)
      Buffer.set_cell(buffer, 5, 5, cell)

      BufferManager.resize(server, 20, 30)

      new_buffer = BufferManager.get_current_buffer(server)
      retrieved = Buffer.get_cell(new_buffer, 5, 5)
      assert retrieved.char == "X"
      assert retrieved.fg == :blue
    end

    test "clips content outside new dimensions", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)
      cell = Cell.new("X")
      Buffer.set_cell(buffer, 8, 8, cell)

      BufferManager.resize(server, 5, 5)

      new_buffer = BufferManager.get_current_buffer(server)
      # Cell at 8,8 should not exist in 5x5 buffer
      retrieved = Buffer.get_cell(new_buffer, 8, 8)
      # Out of bounds returns empty
      assert retrieved.char == " "
    end

    test "resizes both buffers", %{server: server} do
      BufferManager.resize(server, 15, 25)

      current = BufferManager.get_current_buffer(server)
      previous = BufferManager.get_previous_buffer(server)

      assert {15, 25} = Buffer.dimensions(current)
      assert {15, 25} = Buffer.dimensions(previous)
    end
  end

  describe "clear operations" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 10, cols: 10, name: :test_clear)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      # Write some content
      buffer = BufferManager.get_current_buffer(:test_clear)

      for row <- 1..5, col <- 1..5 do
        Buffer.set_cell(buffer, row, col, Cell.new("X"))
      end

      %{server: :test_clear}
    end

    test "clear_current/1 clears entire buffer", %{server: server} do
      BufferManager.clear_current(server)

      buffer = BufferManager.get_current_buffer(server)

      for row <- 1..10, col <- 1..10 do
        cell = Buffer.get_cell(buffer, row, col)
        assert cell.char == " "
      end
    end

    test "clear_row/2 clears single row", %{server: server} do
      BufferManager.clear_row(server, 3)

      buffer = BufferManager.get_current_buffer(server)

      # Row 3 should be empty
      for col <- 1..10 do
        assert Buffer.get_cell(buffer, 3, col).char == " "
      end

      # Row 2 should still have content
      assert Buffer.get_cell(buffer, 2, 1).char == "X"
    end

    test "clear_region/5 clears rectangular area", %{server: server} do
      BufferManager.clear_region(server, 2, 2, 3, 3)

      buffer = BufferManager.get_current_buffer(server)

      # Region 2-4, 2-4 should be clear
      for row <- 2..4, col <- 2..4 do
        assert Buffer.get_cell(buffer, row, col).char == " "
      end

      # Outside region should have content
      assert Buffer.get_cell(buffer, 1, 1).char == "X"
      assert Buffer.get_cell(buffer, 5, 5).char == "X"
    end
  end

  describe "dirty flag" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 5, cols: 5, name: :test_dirty)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_dirty}
    end

    test "starts not dirty", %{server: server} do
      refute BufferManager.dirty?(server)
    end

    test "mark_dirty/1 sets flag", %{server: server} do
      BufferManager.mark_dirty(server)
      assert BufferManager.dirty?(server)
    end

    test "clear_dirty/1 clears flag", %{server: server} do
      BufferManager.mark_dirty(server)
      BufferManager.clear_dirty(server)
      refute BufferManager.dirty?(server)
    end

    test "dirty flag persists across multiple checks", %{server: server} do
      BufferManager.mark_dirty(server)
      assert BufferManager.dirty?(server)
      assert BufferManager.dirty?(server)
      assert BufferManager.dirty?(server)
    end
  end

  describe "convenience functions" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 10, cols: 20, name: :test_convenience)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_convenience}
    end

    test "set_cell/4 sets cell in current buffer", %{server: server} do
      cell = Cell.new("Y", fg: :green)
      assert :ok = BufferManager.set_cell(server, 3, 5, cell)

      retrieved = BufferManager.get_cell(server, 3, 5)
      assert retrieved.char == "Y"
      assert retrieved.fg == :green
    end

    test "set_cells/2 sets multiple cells", %{server: server} do
      cells = [
        {1, 1, Cell.new("A")},
        {1, 2, Cell.new("B")},
        {1, 3, Cell.new("C")}
      ]

      assert :ok = BufferManager.set_cells(server, cells)

      assert BufferManager.get_cell(server, 1, 1).char == "A"
      assert BufferManager.get_cell(server, 1, 2).char == "B"
      assert BufferManager.get_cell(server, 1, 3).char == "C"
    end

    test "get_cell/3 gets cell from current buffer", %{server: server} do
      cell = BufferManager.get_cell(server, 1, 1)
      assert cell.char == " "
      assert cell.fg == :default
    end

    test "write_string/5 writes string to current buffer", %{server: server} do
      written = BufferManager.write_string(server, 2, 3, "Hello")
      assert written == 5

      assert BufferManager.get_cell(server, 2, 3).char == "H"
      assert BufferManager.get_cell(server, 2, 4).char == "e"
      assert BufferManager.get_cell(server, 2, 5).char == "l"
      assert BufferManager.get_cell(server, 2, 6).char == "l"
      assert BufferManager.get_cell(server, 2, 7).char == "o"
    end
  end

  describe "concurrent writes" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 100, cols: 100, name: :test_concurrent)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_concurrent}
    end

    test "multiple processes can write to buffer concurrently", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)

      # Spawn 10 processes, each writing to different rows
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            row = i * 5

            for col <- 1..50 do
              cell = Cell.new("#{rem(i, 10)}")
              Buffer.set_cell(buffer, row, col, cell)
            end
          end)
        end

      # Wait for all tasks
      Task.await_many(tasks)

      # Verify each row has correct content
      for i <- 1..10 do
        row = i * 5
        expected_char = "#{rem(i, 10)}"

        for col <- 1..50 do
          cell = Buffer.get_cell(buffer, row, col)
          assert cell.char == expected_char
        end
      end
    end

    test "overlapping writes don't corrupt buffer", %{server: server} do
      buffer = BufferManager.get_current_buffer(server)

      # Multiple processes write to same cell
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            cell = Cell.new("#{rem(i, 10)}")
            Buffer.set_cell(buffer, 1, 1, cell)
          end)
        end

      Task.await_many(tasks)

      # Cell should have a valid value (one of the writes)
      cell = Buffer.get_cell(buffer, 1, 1)
      assert cell.char in Enum.map(0..9, &Integer.to_string/1)
    end
  end

  describe "termination cleanup" do
    test "cleans up ETS tables on stop" do
      {:ok, pid} = BufferManager.start_link(rows: 5, cols: 5, name: :test_cleanup)

      current = BufferManager.get_current_buffer(:test_cleanup)
      previous = BufferManager.get_previous_buffer(:test_cleanup)

      current_table = current.table
      previous_table = previous.table

      # Verify tables exist
      assert :ets.info(current_table) != :undefined
      assert :ets.info(previous_table) != :undefined

      # Stop the manager
      GenServer.stop(pid)

      # Tables should be deleted
      assert :ets.info(current_table) == :undefined
      assert :ets.info(previous_table) == :undefined
    end

    test "cleans up on crash" do
      # Start in a separate process so we can kill it without killing the test
      test_pid = self()

      spawn(fn ->
        {:ok, pid} = BufferManager.start_link(rows: 5, cols: 5, name: :test_crash_cleanup)

        current = BufferManager.get_current_buffer(:test_crash_cleanup)
        previous = BufferManager.get_previous_buffer(:test_crash_cleanup)

        send(test_pid, {:tables, current.table, previous.table, pid})

        # Keep alive until killed
        receive do
          :stop -> :ok
        end
      end)

      # Get table references
      {current_table, previous_table, manager_pid} =
        receive do
          {:tables, c, p, pid} -> {c, p, pid}
        after
          1000 -> flunk("Timeout waiting for tables")
        end

      # Verify tables exist
      assert :ets.info(current_table) != :undefined
      assert :ets.info(previous_table) != :undefined

      # Kill the manager process
      Process.exit(manager_pid, :kill)

      # Give it a moment to clean up
      Process.sleep(10)

      # Tables should be deleted (ETS tables are owned by the process)
      assert :ets.info(current_table) == :undefined
      assert :ets.info(previous_table) == :undefined
    end
  end

  describe "integration scenarios" do
    setup do
      {:ok, pid} = BufferManager.start_link(rows: 24, cols: 80, name: :test_integration)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{server: :test_integration}
    end

    test "typical render cycle", %{server: server} do
      # 1. Get current buffer and write content
      buffer = BufferManager.get_current_buffer(server)
      Buffer.write_string(buffer, 1, 1, "Hello World")
      BufferManager.mark_dirty(server)

      # 2. Check dirty and render
      assert BufferManager.dirty?(server)
      _current = BufferManager.get_current_buffer(server)
      _previous = BufferManager.get_previous_buffer(server)
      # ... diff and render would happen here ...

      # 3. Swap buffers and clear dirty
      BufferManager.swap_buffers(server)
      BufferManager.clear_dirty(server)

      # 4. Next frame - previous now has "Hello World"
      previous = BufferManager.get_previous_buffer(server)
      assert Buffer.get_cell(previous, 1, 1).char == "H"

      # 5. Current is now empty (ready for next frame)
      current = BufferManager.get_current_buffer(server)
      assert Buffer.get_cell(current, 1, 1).char == " "
    end

    test "resize during usage", %{server: server} do
      # Write content
      BufferManager.write_string(server, 10, 10, "Test")

      # Resize smaller
      BufferManager.resize(server, 8, 8)

      # Content outside new bounds is lost
      assert BufferManager.get_cell(server, 10, 10).char == " "

      # Resize larger
      BufferManager.resize(server, 30, 100)

      # Write in new area
      BufferManager.write_string(server, 25, 50, "New Area")
      assert BufferManager.get_cell(server, 25, 50).char == "N"
    end
  end
end
