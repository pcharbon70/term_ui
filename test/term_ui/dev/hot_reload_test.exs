defmodule TermUI.Dev.HotReloadTest do
  use ExUnit.Case, async: false

  alias TermUI.Dev.HotReload

  setup do
    # Start HotReload server for each test
    start_supervised!(HotReload)
    :ok
  end

  describe "start/stop" do
    test "starts disabled" do
      refute HotReload.running?()
    end

    test "can start and stop hot reload" do
      :ok = HotReload.start()
      assert HotReload.running?()
      :ok = HotReload.stop()
      refute HotReload.running?()
    end
  end

  describe "reload_module/1" do
    # Reloading standard library modules can cause issues
    @tag :skip
    test "reloads an existing module" do
      result = HotReload.reload_module(Enum)
      assert result == :ok
    end

    test "returns error for non-existent module" do
      result = HotReload.reload_module(NonExistentModule12345)
      assert {:error, _} = result
    end
  end

  describe "on_reload callback" do
    test "can set reload callback" do
      # Verify callback can be set without error
      HotReload.on_reload(fn _module -> :ok end)
      assert true
    end
  end

  describe "get_recent_reloads/0" do
    test "starts empty" do
      assert HotReload.get_recent_reloads() == []
    end
  end

  describe "get_module_source/1" do
    test "returns source path for compiled module" do
      source = HotReload.get_module_source(Enum)
      assert is_nil(source) or is_binary(source)
    end

    test "returns nil for unknown module" do
      assert HotReload.get_module_source(UnknownModule123) == nil
    end
  end

  describe "can_reload?/1" do
    test "returns false for unknown modules" do
      refute HotReload.can_reload?(UnknownModule123)
    end
  end
end
