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

  describe "put_backend_state/2" do
    test "updates backend_state" do
      state = State.new_raw()
      updated = State.put_backend_state(state, %{cursor: {1, 1}})

      assert updated.backend_state == %{cursor: {1, 1}}
    end

    test "preserves other fields" do
      state = State.new_tty(%{colors: :true_color})
      state = State.put_size(state, {24, 80})
      state = State.mark_initialized(state)

      updated = State.put_backend_state(state, %{some: :state})

      assert updated.backend_state == %{some: :state}
      assert updated.backend_module == TermUI.Backend.TTY
      assert updated.mode == :tty
      assert updated.capabilities == %{colors: :true_color}
      assert updated.size == {24, 80}
      assert updated.initialized == true
    end

    test "accepts any term as backend_state" do
      state = State.new_raw()

      assert State.put_backend_state(state, :atom).backend_state == :atom
      assert State.put_backend_state(state, [1, 2, 3]).backend_state == [1, 2, 3]
      assert State.put_backend_state(state, "string").backend_state == "string"
      assert State.put_backend_state(state, nil).backend_state == nil
    end

    test "returns new struct (immutability)" do
      original = State.new_raw()
      updated = State.put_backend_state(original, %{new: :state})

      assert original.backend_state == nil
      assert updated.backend_state == %{new: :state}
      refute original == updated
    end
  end

  describe "put_size/2" do
    test "updates size with tuple" do
      state = State.new_tty(%{})
      updated = State.put_size(state, {24, 80})

      assert updated.size == {24, 80}
    end

    test "updates size with nil" do
      state = State.new_tty(%{})
      state = State.put_size(state, {24, 80})
      updated = State.put_size(state, nil)

      assert updated.size == nil
    end

    test "accepts different dimension values" do
      state = State.new_tty(%{})

      assert State.put_size(state, {1, 1}).size == {1, 1}
      assert State.put_size(state, {50, 120}).size == {50, 120}
      assert State.put_size(state, {1000, 2000}).size == {1000, 2000}
    end

    test "preserves other fields" do
      state = State.new_tty(%{colors: :true_color})
      state = State.put_backend_state(state, %{some: :state})
      state = State.mark_initialized(state)

      updated = State.put_size(state, {30, 100})

      assert updated.size == {30, 100}
      assert updated.backend_module == TermUI.Backend.TTY
      assert updated.mode == :tty
      assert updated.capabilities == %{colors: :true_color}
      assert updated.backend_state == %{some: :state}
      assert updated.initialized == true
    end

    test "returns new struct (immutability)" do
      original = State.new_tty(%{})
      updated = State.put_size(original, {24, 80})

      assert original.size == nil
      assert updated.size == {24, 80}
      refute original == updated
    end
  end

  describe "put_capabilities/2" do
    test "updates capabilities" do
      state = State.new_tty(%{colors: :basic})
      updated = State.put_capabilities(state, %{colors: :true_color, unicode: true})

      assert updated.capabilities == %{colors: :true_color, unicode: true}
    end

    test "replaces entire map (does not merge)" do
      state = State.new_tty(%{colors: :basic, unicode: true, terminal: true})
      updated = State.put_capabilities(state, %{colors: :true_color})

      assert updated.capabilities == %{colors: :true_color}
      refute Map.has_key?(updated.capabilities, :unicode)
      refute Map.has_key?(updated.capabilities, :terminal)
    end

    test "accepts empty map" do
      state = State.new_tty(%{colors: :true_color})
      updated = State.put_capabilities(state, %{})

      assert updated.capabilities == %{}
    end

    test "raises when capabilities is not a map" do
      state = State.new_tty(%{})

      assert_raise FunctionClauseError, fn ->
        State.put_capabilities(state, :not_a_map)
      end

      assert_raise FunctionClauseError, fn ->
        State.put_capabilities(state, [colors: :true_color])
      end
    end

    test "preserves other fields" do
      state = State.new_tty(%{colors: :basic})
      state = State.put_size(state, {24, 80})
      state = State.put_backend_state(state, %{some: :state})
      state = State.mark_initialized(state)

      updated = State.put_capabilities(state, %{colors: :true_color})

      assert updated.capabilities == %{colors: :true_color}
      assert updated.backend_module == TermUI.Backend.TTY
      assert updated.mode == :tty
      assert updated.size == {24, 80}
      assert updated.backend_state == %{some: :state}
      assert updated.initialized == true
    end

    test "returns new struct (immutability)" do
      original = State.new_tty(%{colors: :basic})
      updated = State.put_capabilities(original, %{colors: :true_color})

      assert original.capabilities == %{colors: :basic}
      assert updated.capabilities == %{colors: :true_color}
      refute original == updated
    end
  end

  describe "mark_initialized/1" do
    test "sets initialized to true" do
      state = State.new_tty(%{})
      assert state.initialized == false

      updated = State.mark_initialized(state)
      assert updated.initialized == true
    end

    test "is idempotent" do
      state = State.new_tty(%{})
      state = State.mark_initialized(state)
      assert state.initialized == true

      state = State.mark_initialized(state)
      assert state.initialized == true
    end

    test "preserves other fields" do
      state = State.new_tty(%{colors: :true_color})
      state = State.put_size(state, {24, 80})
      state = State.put_backend_state(state, %{some: :state})

      updated = State.mark_initialized(state)

      assert updated.initialized == true
      assert updated.backend_module == TermUI.Backend.TTY
      assert updated.mode == :tty
      assert updated.capabilities == %{colors: :true_color}
      assert updated.size == {24, 80}
      assert updated.backend_state == %{some: :state}
    end

    test "returns new struct (immutability)" do
      original = State.new_tty(%{})
      updated = State.mark_initialized(original)

      assert original.initialized == false
      assert updated.initialized == true
      refute original == updated
    end
  end

  describe "update function documentation" do
    test "put_backend_state/2 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :put_backend_state, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "put_backend_state/2 should have documentation"
    end

    test "put_size/2 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :put_size, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "put_size/2 should have documentation"
    end

    test "put_capabilities/2 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :put_capabilities, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "put_capabilities/2 should have documentation"
    end

    test "mark_initialized/1 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(State)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :mark_initialized, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1, "mark_initialized/1 should have documentation"
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
