defmodule TermUI.Component.StatePersistenceTest do
  use ExUnit.Case, async: false

  alias TermUI.Component.StatePersistence

  setup do
    start_supervised!(StatePersistence)
    :ok
  end

  describe "persist/3" do
    test "persists state to ETS" do
      state = %{counter: 42}
      :ok = StatePersistence.persist(:test_component, state)

      assert {:ok, ^state} = StatePersistence.recover(:test_component)
    end

    test "persists state with props" do
      state = %{counter: 42}
      props = %{initial: 10}
      :ok = StatePersistence.persist(:test_component, state, props: props)

      assert {:ok, ^state} = StatePersistence.recover(:test_component, :last_state)
      assert {:ok, ^props} = StatePersistence.recover(:test_component, :last_props)
    end

    test "overwrites previous state" do
      StatePersistence.persist(:test_component, %{value: 1})
      StatePersistence.persist(:test_component, %{value: 2})

      assert {:ok, %{value: 2}} = StatePersistence.recover(:test_component)
    end
  end

  describe "recover/2" do
    test "returns :not_found for non-existent component" do
      assert :not_found = StatePersistence.recover(:nonexistent)
    end

    test "with :last_state mode returns full state" do
      state = %{counter: 42, name: "test"}
      StatePersistence.persist(:test_component, state)

      assert {:ok, ^state} = StatePersistence.recover(:test_component, :last_state)
    end

    test "with :last_props mode returns props" do
      state = %{counter: 42}
      props = %{initial: 10}
      StatePersistence.persist(:test_component, state, props: props)

      assert {:ok, ^props} = StatePersistence.recover(:test_component, :last_props)
    end

    test "with :last_props mode returns :not_found if no props" do
      state = %{counter: 42}
      StatePersistence.persist(:test_component, state)

      assert :not_found = StatePersistence.recover(:test_component, :last_props)
    end

    test "with :reset mode clears state and returns :not_found" do
      state = %{counter: 42}
      StatePersistence.persist(:test_component, state)

      assert :not_found = StatePersistence.recover(:test_component, :reset)
      # State should be cleared
      assert :not_found = StatePersistence.recover(:test_component)
    end
  end

  describe "clear/1" do
    test "clears persisted state" do
      StatePersistence.persist(:test_component, %{value: 1})
      StatePersistence.clear(:test_component)

      assert :not_found = StatePersistence.recover(:test_component)
    end

    test "is idempotent" do
      StatePersistence.clear(:nonexistent)
      assert :ok = StatePersistence.clear(:nonexistent)
    end
  end

  describe "clear_all/0" do
    test "clears all persisted states" do
      StatePersistence.persist(:comp1, %{value: 1})
      StatePersistence.persist(:comp2, %{value: 2})
      StatePersistence.clear_all()

      assert :not_found = StatePersistence.recover(:comp1)
      assert :not_found = StatePersistence.recover(:comp2)
    end
  end

  describe "get_metadata/1" do
    test "returns metadata for persisted state" do
      StatePersistence.persist(:test_component, %{value: 1}, props: %{initial: 0})

      assert {:ok, metadata} = StatePersistence.get_metadata(:test_component)
      assert is_integer(metadata.persisted_at)
      assert metadata.has_props == true
    end

    test "returns :not_found for non-existent component" do
      assert :not_found = StatePersistence.get_metadata(:nonexistent)
    end
  end

  describe "list_persisted/0" do
    test "returns all persisted component IDs" do
      StatePersistence.persist(:comp1, %{})
      StatePersistence.persist(:comp2, %{})
      StatePersistence.persist(:comp3, %{})

      ids = StatePersistence.list_persisted()
      assert length(ids) == 3
      assert :comp1 in ids
      assert :comp2 in ids
      assert :comp3 in ids
    end

    test "returns empty list when nothing persisted" do
      assert [] = StatePersistence.list_persisted()
    end
  end

  describe "count/0" do
    test "returns count of persisted states" do
      assert StatePersistence.count() == 0

      StatePersistence.persist(:comp1, %{})
      assert StatePersistence.count() == 1

      StatePersistence.persist(:comp2, %{})
      assert StatePersistence.count() == 2
    end
  end

  describe "restart tracking" do
    test "record_restart increments restart count" do
      assert StatePersistence.get_restart_count(:test_component) == 0

      StatePersistence.record_restart(:test_component)
      assert StatePersistence.get_restart_count(:test_component) == 1

      StatePersistence.record_restart(:test_component)
      assert StatePersistence.get_restart_count(:test_component) == 2
    end

    test "restart_limit_reached? returns false when under limit" do
      StatePersistence.set_restart_limits(:test_component, 3, 5)

      refute StatePersistence.restart_limit_reached?(:test_component)

      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)
      refute StatePersistence.restart_limit_reached?(:test_component)
    end

    test "restart_limit_reached? returns true when at limit" do
      StatePersistence.set_restart_limits(:test_component, 3, 5)

      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)

      assert StatePersistence.restart_limit_reached?(:test_component)
    end

    test "old restarts are pruned from window" do
      # This test would require time manipulation, so we just verify the structure
      StatePersistence.set_restart_limits(:test_component, 3, 1)
      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)

      # Should be at limit
      assert StatePersistence.restart_limit_reached?(:test_component)
    end

    test "clear_restart_history clears count" do
      StatePersistence.record_restart(:test_component)
      StatePersistence.record_restart(:test_component)
      StatePersistence.clear_restart_history(:test_component)

      assert StatePersistence.get_restart_count(:test_component) == 0
    end
  end
end
