defmodule TermUI.ComponentRegistryTest do
  use ExUnit.Case, async: false

  alias TermUI.ComponentRegistry

  setup do
    start_supervised!(ComponentRegistry)
    :ok
  end

  describe "register/3" do
    test "registers component successfully" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      assert :ok = ComponentRegistry.register(:test_id, pid, TestModule)
    end

    test "fails if id already registered" do
      pid1 = spawn(fn -> Process.sleep(10_000) end)
      pid2 = spawn(fn -> Process.sleep(10_000) end)

      :ok = ComponentRegistry.register(:same_id, pid1, TestModule)

      assert {:error, :already_registered} =
               ComponentRegistry.register(:same_id, pid2, TestModule)
    end

    test "can register with reference as id" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      ref = make_ref()
      assert :ok = ComponentRegistry.register(ref, pid, TestModule)
      assert {:ok, ^pid} = ComponentRegistry.lookup(ref)
    end
  end

  describe "unregister/1" do
    test "unregisters component" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:to_remove, pid, TestModule)
      assert ComponentRegistry.registered?(:to_remove)

      :ok = ComponentRegistry.unregister(:to_remove)
      refute ComponentRegistry.registered?(:to_remove)
    end

    test "returns ok for non-existent id" do
      assert :ok = ComponentRegistry.unregister(:not_registered)
    end
  end

  describe "lookup/1" do
    test "returns pid for registered component" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:lookup_test, pid, TestModule)

      assert {:ok, ^pid} = ComponentRegistry.lookup(:lookup_test)
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = ComponentRegistry.lookup(:nonexistent)
    end
  end

  describe "lookup_id/1" do
    test "returns id for registered pid" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:reverse_lookup, pid, TestModule)

      assert {:ok, :reverse_lookup} = ComponentRegistry.lookup_id(pid)
    end

    test "returns error for non-registered pid" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      assert {:error, :not_found} = ComponentRegistry.lookup_id(pid)
    end
  end

  describe "get_info/1" do
    test "returns full component info" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:info_test, pid, MyModule)

      {:ok, info} = ComponentRegistry.get_info(:info_test)
      assert info.id == :info_test
      assert info.pid == pid
      assert info.module == MyModule
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = ComponentRegistry.get_info(:nope)
    end
  end

  describe "list_all/0" do
    test "returns all registered components" do
      pid1 = spawn(fn -> Process.sleep(10_000) end)
      pid2 = spawn(fn -> Process.sleep(10_000) end)

      :ok = ComponentRegistry.register(:comp1, pid1, Mod1)
      :ok = ComponentRegistry.register(:comp2, pid2, Mod2)

      all = ComponentRegistry.list_all()
      assert length(all) == 2

      ids = Enum.map(all, & &1.id)
      assert :comp1 in ids
      assert :comp2 in ids
    end

    test "returns empty list when no components" do
      assert ComponentRegistry.list_all() == []
    end
  end

  describe "count/0" do
    test "returns correct count" do
      pid1 = spawn(fn -> Process.sleep(10_000) end)
      pid2 = spawn(fn -> Process.sleep(10_000) end)

      assert ComponentRegistry.count() == 0

      :ok = ComponentRegistry.register(:count1, pid1, Mod1)
      assert ComponentRegistry.count() == 1

      :ok = ComponentRegistry.register(:count2, pid2, Mod2)
      assert ComponentRegistry.count() == 2
    end
  end

  describe "registered?/1" do
    test "returns true for registered id" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:exists, pid, TestModule)

      assert ComponentRegistry.registered?(:exists)
    end

    test "returns false for non-registered id" do
      refute ComponentRegistry.registered?(:does_not_exist)
    end
  end

  describe "clear/0" do
    test "removes all registrations" do
      pid1 = spawn(fn -> Process.sleep(10_000) end)
      pid2 = spawn(fn -> Process.sleep(10_000) end)

      :ok = ComponentRegistry.register(:clear1, pid1, Mod1)
      :ok = ComponentRegistry.register(:clear2, pid2, Mod2)

      assert ComponentRegistry.count() == 2

      :ok = ComponentRegistry.clear()

      assert ComponentRegistry.count() == 0
      refute ComponentRegistry.registered?(:clear1)
      refute ComponentRegistry.registered?(:clear2)
    end
  end

  describe "automatic cleanup" do
    test "unregisters when process dies" do
      pid = spawn(fn -> Process.sleep(100) end)
      :ok = ComponentRegistry.register(:auto_cleanup, pid, TestModule)

      assert ComponentRegistry.registered?(:auto_cleanup)

      # Wait for process to die
      Process.sleep(150)

      refute ComponentRegistry.registered?(:auto_cleanup)
    end

    test "unregisters when process is killed" do
      pid = spawn(fn -> Process.sleep(10_000) end)
      :ok = ComponentRegistry.register(:kill_test, pid, TestModule)

      Process.exit(pid, :kill)

      # Give time for monitor to trigger
      Process.sleep(50)

      refute ComponentRegistry.registered?(:kill_test)
    end
  end
end
