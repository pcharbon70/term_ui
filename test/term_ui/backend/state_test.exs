defmodule TermUI.Backend.StateTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.State

  describe "module structure" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(State)
    end

    test "defines a struct" do
      assert function_exported?(State, :__struct__, 0)
      assert function_exported?(State, :__struct__, 1)
    end
  end

  describe "struct creation with required fields" do
    test "creates struct with backend_module and mode" do
      state = %State{backend_module: SomeBackend, mode: :raw}

      assert state.backend_module == SomeBackend
      assert state.mode == :raw
    end

    test "raises when backend_module is missing" do
      assert_raise ArgumentError, ~r/:backend_module/, fn ->
        struct!(State, mode: :raw)
      end
    end

    test "raises when mode is missing" do
      assert_raise ArgumentError, ~r/:mode/, fn ->
        struct!(State, backend_module: SomeBackend)
      end
    end

    test "raises when both required keys are missing" do
      assert_raise ArgumentError, fn ->
        struct!(State, [])
      end
    end
  end

  describe "default values" do
    test "backend_state defaults to nil" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.backend_state == nil
    end

    test "capabilities defaults to empty map" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.capabilities == %{}
    end

    test "size defaults to nil" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.size == nil
    end

    test "initialized defaults to false" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.initialized == false
    end
  end

  describe "struct creation with all fields" do
    test "accepts all fields" do
      capabilities = %{colors: :true_color, unicode: true}

      state = %State{
        backend_module: TermUI.Backend.TTY,
        backend_state: %{some: :state},
        mode: :tty,
        capabilities: capabilities,
        size: {24, 80},
        initialized: true
      }

      assert state.backend_module == TermUI.Backend.TTY
      assert state.backend_state == %{some: :state}
      assert state.mode == :tty
      assert state.capabilities == capabilities
      assert state.size == {24, 80}
      assert state.initialized == true
    end
  end

  describe "mode field" do
    test "accepts :raw mode" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.mode == :raw
    end

    test "accepts :tty mode" do
      state = %State{backend_module: SomeBackend, mode: :tty}
      assert state.mode == :tty
    end
  end

  describe "size field" do
    test "accepts nil" do
      state = %State{backend_module: SomeBackend, mode: :raw, size: nil}
      assert state.size == nil
    end

    test "accepts {rows, cols} tuple" do
      state = %State{backend_module: SomeBackend, mode: :raw, size: {24, 80}}
      assert state.size == {24, 80}
    end

    test "accepts different dimension values" do
      state = %State{backend_module: SomeBackend, mode: :raw, size: {50, 120}}
      assert state.size == {50, 120}
    end
  end

  describe "capabilities field" do
    test "accepts empty map" do
      state = %State{backend_module: SomeBackend, mode: :raw, capabilities: %{}}
      assert state.capabilities == %{}
    end

    test "accepts capabilities map with expected keys" do
      caps = %{
        colors: :color_256,
        unicode: true,
        dimensions: {24, 80},
        terminal: true
      }

      state = %State{backend_module: SomeBackend, mode: :tty, capabilities: caps}
      assert state.capabilities == caps
      assert state.capabilities.colors == :color_256
      assert state.capabilities.unicode == true
    end
  end

  describe "struct updates" do
    test "can update backend_state" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      updated = %{state | backend_state: %{cursor: {1, 1}}}

      assert updated.backend_state == %{cursor: {1, 1}}
      assert updated.backend_module == SomeBackend
    end

    test "can update size" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      updated = %{state | size: {30, 100}}

      assert updated.size == {30, 100}
    end

    test "can update initialized flag" do
      state = %State{backend_module: SomeBackend, mode: :raw}
      assert state.initialized == false

      updated = %{state | initialized: true}
      assert updated.initialized == true
    end

    test "can update multiple fields at once" do
      state = %State{backend_module: SomeBackend, mode: :raw}

      updated = %{state | size: {24, 80}, initialized: true, backend_state: :ready}

      assert updated.size == {24, 80}
      assert updated.initialized == true
      assert updated.backend_state == :ready
    end

    test "updates are immutable" do
      original = %State{backend_module: SomeBackend, mode: :raw}
      _updated = %{original | initialized: true}

      # Original is unchanged
      assert original.initialized == false
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(State)
      assert module_doc != :none
      assert module_doc != :hidden
    end

    test "type t is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :t, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "type t should be defined"
    end

    test "type mode is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :mode, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "type mode should be defined"
    end

    test "type dimensions is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :dimensions, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "type dimensions should be defined"
    end
  end

  describe "new/2 constructor" do
    test "creates state with backend_module and mode" do
      state = State.new(SomeBackend, mode: :tty)

      assert state.backend_module == SomeBackend
      assert state.mode == :tty
    end

    test "raises when mode is missing" do
      assert_raise ArgumentError, "the :mode option is required", fn ->
        State.new(SomeBackend)
      end
    end

    test "raises when mode is missing from options" do
      assert_raise ArgumentError, "the :mode option is required", fn ->
        State.new(SomeBackend, capabilities: %{})
      end
    end

    test "accepts all optional fields" do
      caps = %{colors: :true_color}

      state =
        State.new(SomeBackend,
          mode: :tty,
          backend_state: %{some: :state},
          capabilities: caps,
          size: {24, 80},
          initialized: true
        )

      assert state.backend_module == SomeBackend
      assert state.mode == :tty
      assert state.backend_state == %{some: :state}
      assert state.capabilities == caps
      assert state.size == {24, 80}
      assert state.initialized == true
    end

    test "applies defaults for omitted optional fields" do
      state = State.new(SomeBackend, mode: :raw)

      assert state.backend_state == nil
      assert state.capabilities == %{}
      assert state.size == nil
      assert state.initialized == false
    end

    test "accepts :raw mode" do
      state = State.new(SomeBackend, mode: :raw)
      assert state.mode == :raw
    end

    test "accepts :tty mode" do
      state = State.new(SomeBackend, mode: :tty)
      assert state.mode == :tty
    end
  end

  describe "new_raw/0 and new_raw/1 constructor" do
    test "creates raw mode state with defaults" do
      state = State.new_raw()

      assert state.backend_module == TermUI.Backend.Raw
      assert state.mode == :raw
      assert state.backend_state == nil
      assert state.capabilities == %{}
      assert state.size == nil
      assert state.initialized == false
    end

    test "accepts backend_state" do
      backend_state = %{raw_mode_started: true}
      state = State.new_raw(backend_state)

      assert state.backend_module == TermUI.Backend.Raw
      assert state.mode == :raw
      assert state.backend_state == backend_state
    end

    test "accepts any term as backend_state" do
      state = State.new_raw(:ready)
      assert state.backend_state == :ready

      state = State.new_raw([1, 2, 3])
      assert state.backend_state == [1, 2, 3]

      state = State.new_raw({:some, :tuple})
      assert state.backend_state == {:some, :tuple}
    end
  end

  describe "new_tty/1 and new_tty/2 constructor" do
    test "creates tty mode state with capabilities" do
      caps = %{colors: :color_256, unicode: true}
      state = State.new_tty(caps)

      assert state.backend_module == TermUI.Backend.TTY
      assert state.mode == :tty
      assert state.capabilities == caps
      assert state.backend_state == nil
      assert state.size == nil
      assert state.initialized == false
    end

    test "accepts backend_state as second argument" do
      caps = %{colors: :true_color}
      backend_state = %{some: :state}
      state = State.new_tty(caps, backend_state)

      assert state.backend_module == TermUI.Backend.TTY
      assert state.mode == :tty
      assert state.capabilities == caps
      assert state.backend_state == backend_state
    end

    test "accepts empty capabilities map" do
      state = State.new_tty(%{})

      assert state.capabilities == %{}
    end

    test "raises when capabilities is not a map" do
      assert_raise FunctionClauseError, fn ->
        State.new_tty(:not_a_map)
      end

      assert_raise FunctionClauseError, fn ->
        State.new_tty([colors: :true_color])
      end
    end

    test "preserves all capability keys" do
      caps = %{
        colors: :true_color,
        unicode: true,
        dimensions: {24, 80},
        terminal: true,
        custom: :value
      }

      state = State.new_tty(caps)

      assert state.capabilities == caps
      assert state.capabilities.colors == :true_color
      assert state.capabilities.unicode == true
      assert state.capabilities.dimensions == {24, 80}
      assert state.capabilities.terminal == true
      assert state.capabilities.custom == :value
    end
  end

  describe "constructor documentation" do
    test "new/2 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :new, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "new/2 should have documentation"
    end

    test "new_raw/1 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :new_raw, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "new_raw/1 should have documentation"
    end

    test "new_tty/2 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :new_tty, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "new_tty/2 should have documentation"
    end
  end

  describe "typical usage patterns" do
    test "raw mode state creation" do
      # Simulates what happens after Selector.select() returns {:raw, raw_state}
      raw_state = %{raw_mode_started: true}

      state = %State{
        backend_module: TermUI.Backend.Raw,
        backend_state: raw_state,
        mode: :raw,
        capabilities: %{},
        initialized: false
      }

      assert state.mode == :raw
      assert state.backend_state.raw_mode_started == true
    end

    test "tty mode state creation" do
      # Simulates what happens after Selector.select() returns {:tty, capabilities}
      capabilities = %{
        colors: :color_256,
        unicode: true,
        dimensions: {24, 80},
        terminal: true
      }

      state = %State{
        backend_module: TermUI.Backend.TTY,
        backend_state: nil,
        mode: :tty,
        capabilities: capabilities,
        initialized: false
      }

      assert state.mode == :tty
      assert state.capabilities.colors == :color_256
      assert state.size == nil
    end

    test "state lifecycle: creation -> initialization -> updates" do
      # Create initial state
      state = %State{
        backend_module: TermUI.Backend.TTY,
        mode: :tty,
        capabilities: %{colors: :true_color}
      }

      assert state.initialized == false
      assert state.size == nil

      # Mark as initialized and cache size
      state = %{state | initialized: true, size: {24, 80}}

      assert state.initialized == true
      assert state.size == {24, 80}

      # Update size after resize
      state = %{state | size: {30, 100}}

      assert state.size == {30, 100}
    end
  end
end
