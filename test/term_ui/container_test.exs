defmodule TermUI.ContainerTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  # Simple panel container
  defmodule Panel do
    use TermUI.Container

    @impl true
    def init(props) do
      {:ok, %{title: props[:title] || "Panel"}}
    end

    @impl true
    def children(_state) do
      [
        {TermUI.ContainerTest.FakeLabel, %{text: "Header"}, :header},
        {TermUI.ContainerTest.FakeLabel, %{text: "Content"}, :content}
      ]
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text(state.title)
    end
  end

  # Container with custom layout
  defmodule HorizontalLayout do
    use TermUI.Container

    @impl true
    def init(_props) do
      {:ok, %{}}
    end

    @impl true
    def children(_state) do
      [
        {TermUI.ContainerTest.FakeLabel, %{text: "Left"}, :left},
        {TermUI.ContainerTest.FakeLabel, %{text: "Right"}, :right}
      ]
    end

    @impl true
    def layout(children, _state, area) do
      half_width = div(area.width, 2)

      children
      |> Enum.with_index()
      |> Enum.map(fn {child, i} ->
        child_area = %{
          x: area.x + i * half_width,
          y: area.y,
          width: half_width,
          height: area.height
        }

        {child, child_area}
      end)
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      empty()
    end
  end

  # Container with event routing
  defmodule RoutingContainer do
    use TermUI.Container

    @impl true
    def init(props) do
      {:ok, %{focused: props[:focused] || :first}}
    end

    @impl true
    def children(_state) do
      [
        {TermUI.ContainerTest.FakeLabel, %{}, :first},
        {TermUI.ContainerTest.FakeLabel, %{}, :second}
      ]
    end

    @impl true
    def handle_event({:focus, id}, state) do
      {:ok, %{state | focused: id}}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def route_event(_event, state) do
      {:child, state.focused}
    end

    @impl true
    def render(_state, _area) do
      empty()
    end
  end

  # Container with child messages
  defmodule MessageContainer do
    use TermUI.Container

    @impl true
    def init(_props) do
      {:ok, %{messages: []}}
    end

    @impl true
    def children(_state) do
      [{TermUI.ContainerTest.FakeLabel, %{}, :child}]
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def handle_child_message(child_id, message, state) do
      {:ok, %{state | messages: [{child_id, message} | state.messages]}}
    end

    @impl true
    def render(_state, _area) do
      empty()
    end
  end

  # Fake component for testing
  defmodule FakeLabel do
    use TermUI.Component

    @impl true
    def render(props, _area) do
      text(props[:text] || "")
    end
  end

  # Container with no ID children
  defmodule NoIdContainer do
    use TermUI.Container

    @impl true
    def init(_props) do
      {:ok, %{}}
    end

    @impl true
    def children(_state) do
      [
        {TermUI.ContainerTest.FakeLabel, %{text: "No ID 1"}},
        {TermUI.ContainerTest.FakeLabel, %{text: "No ID 2"}}
      ]
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      empty()
    end
  end

  describe "children/1" do
    test "returns list of child specs" do
      {:ok, state} = Panel.init(%{})
      children = Panel.children(state)

      assert length(children) == 2
      {mod1, props1, id1} = Enum.at(children, 0)
      {mod2, props2, id2} = Enum.at(children, 1)
      assert mod1 == __MODULE__.FakeLabel
      assert props1.text == "Header"
      assert id1 == :header
      assert mod2 == __MODULE__.FakeLabel
      assert props2.text == "Content"
      assert id2 == :content
    end

    test "child_spec with explicit id" do
      {:ok, state} = Panel.init(%{})
      [{module, props, id} | _] = Panel.children(state)

      assert module == __MODULE__.FakeLabel
      assert props.text == "Header"
      assert id == :header
    end

    test "child_spec without id" do
      {:ok, state} = NoIdContainer.init(%{})
      children = NoIdContainer.children(state)

      [{mod1, props1}, {mod2, props2}] = children
      assert mod1 == __MODULE__.FakeLabel
      assert props1.text == "No ID 1"
      assert mod2 == __MODULE__.FakeLabel
      assert props2.text == "No ID 2"
    end
  end

  describe "layout/3" do
    test "default layout stacks vertically" do
      {:ok, state} = Panel.init(%{})
      children = Panel.children(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      layout = Panel.layout(children, state, area)

      assert length(layout) == 2
      {_child1, area1} = Enum.at(layout, 0)
      {_child2, area2} = Enum.at(layout, 1)

      assert area1.y == 0
      assert area1.height == 12
      assert area2.y == 12
      assert area2.height == 12
    end

    test "custom horizontal layout" do
      {:ok, state} = HorizontalLayout.init(%{})
      children = HorizontalLayout.children(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      layout = HorizontalLayout.layout(children, state, area)

      {_child1, area1} = Enum.at(layout, 0)
      {_child2, area2} = Enum.at(layout, 1)

      assert area1.x == 0
      assert area1.width == 40
      assert area2.x == 40
      assert area2.width == 40
    end

    test "layout preserves child specs" do
      {:ok, state} = Panel.init(%{})
      children = Panel.children(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      layout = Panel.layout(children, state, area)

      {{module, props, id}, _area} = Enum.at(layout, 0)
      assert module == __MODULE__.FakeLabel
      assert props == %{text: "Header"}
      assert id == :header
    end

    test "empty children list" do
      # Custom container with no children
      defmodule EmptyContainer do
        use TermUI.Container

        def init(_props), do: {:ok, %{}}
        def children(_state), do: []
        def handle_event(_event, state), do: {:ok, state}
        def render(_state, _area), do: empty()
      end

      {:ok, state} = EmptyContainer.init(%{})
      children = EmptyContainer.children(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      layout = EmptyContainer.layout(children, state, area)
      assert layout == []
    end
  end

  describe "route_event/2" do
    test "default routes to self" do
      {:ok, state} = Panel.init(%{})
      target = Panel.route_event(:some_event, state)
      assert target == :self
    end

    test "custom routing to child" do
      {:ok, state} = RoutingContainer.init(%{focused: :second})
      target = RoutingContainer.route_event(:key_press, state)
      assert target == {:child, :second}
    end

    test "routing changes with state" do
      {:ok, state} = RoutingContainer.init(%{focused: :first})
      assert RoutingContainer.route_event(:event, state) == {:child, :first}

      {:ok, state} = RoutingContainer.handle_event({:focus, :second}, state)
      assert RoutingContainer.route_event(:event, state) == {:child, :second}
    end
  end

  describe "handle_child_message/3" do
    test "receives messages from children" do
      {:ok, state} = MessageContainer.init(%{})
      {:ok, state} = MessageContainer.handle_child_message(:child, :submitted, state)

      assert state.messages == [{:child, :submitted}]
    end

    test "accumulates messages" do
      {:ok, state} = MessageContainer.init(%{})
      {:ok, state} = MessageContainer.handle_child_message(:child, :first, state)
      {:ok, state} = MessageContainer.handle_child_message(:child, :second, state)

      assert length(state.messages) == 2
    end

    test "default does nothing" do
      {:ok, state} = Panel.init(%{})
      {:ok, new_state} = Panel.handle_child_message(:header, :message, state)
      assert new_state == state
    end
  end

  describe "helper functions" do
    test "normalize_child_spec adds id to 2-tuple" do
      {module, props, id} = Panel.normalize_child_spec({FakeLabel, %{text: "Test"}})
      assert module == FakeLabel
      assert props.text == "Test"
      assert is_reference(id)
    end

    test "normalize_child_spec preserves 3-tuple" do
      {module, props, id} = Panel.normalize_child_spec({FakeLabel, %{text: "Test"}, :my_id})
      assert module == FakeLabel
      assert props.text == "Test"
      assert id == :my_id
    end

    test "child_id extracts id" do
      assert Panel.child_id({FakeLabel, %{}, :test_id}) == :test_id
      assert Panel.child_id({FakeLabel, %{}}) == nil
    end

    test "child_module extracts module" do
      assert Panel.child_module({FakeLabel, %{}, :id}) == FakeLabel
      assert Panel.child_module({FakeLabel, %{}}) == FakeLabel
    end

    test "child_props extracts props" do
      assert Panel.child_props({FakeLabel, %{text: "Hi"}, :id}) == %{text: "Hi"}
      assert Panel.child_props({FakeLabel, %{text: "Hi"}}) == %{text: "Hi"}
    end
  end

  describe "__using__ macro" do
    test "provides default implementations" do
      {:ok, state} = Panel.init(%{})

      # Default terminate
      assert Panel.terminate(:normal, state) == :ok

      # Default handle_info
      {:ok, new_state} = Panel.handle_info(:message, state)
      assert new_state == state

      # Default handle_call
      {:reply, :ok, new_state} = Panel.handle_call(:request, self(), state)
      assert new_state == state
    end

    test "imports helpers" do
      {:ok, state} = Panel.init(%{})
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = Panel.render(state, area)
      assert %RenderNode{} = result
    end
  end

  describe "state management" do
    test "init receives props" do
      {:ok, state} = Panel.init(%{title: "My Panel"})
      assert state.title == "My Panel"
    end

    test "handle_event updates state" do
      {:ok, state} = RoutingContainer.init(%{focused: :first})
      {:ok, state} = RoutingContainer.handle_event({:focus, :second}, state)
      assert state.focused == :second
    end
  end

  describe "render/2" do
    test "can return content" do
      {:ok, state} = Panel.init(%{title: "Test"})
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = Panel.render(state, area)
      assert result.content == "Test"
    end

    test "can return empty" do
      {:ok, state} = HorizontalLayout.init(%{})
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = HorizontalLayout.render(state, area)
      assert result.type == :empty
    end
  end
end
