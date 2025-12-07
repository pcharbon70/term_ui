defmodule TermUI.Widgets.TextInput.LineTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.TextInput.Line

  import ExUnit.CaptureIO

  describe "new/1" do
    test "creates props with defaults" do
      props = Line.new()

      assert props.prompt == ""
      assert props.value == ""
      assert props.label == nil
      assert props.validator == nil
      assert props.placeholder == ""
    end

    test "creates props with custom prompt" do
      props = Line.new(prompt: "Enter name: ")

      assert props.prompt == "Enter name: "
    end

    test "creates props with all options" do
      validator = fn x -> {:ok, x} end

      props =
        Line.new(
          prompt: "Name: ",
          value: "initial",
          label: "User Name",
          validator: validator,
          placeholder: "Type here"
        )

      assert props.prompt == "Name: "
      assert props.value == "initial"
      assert props.label == "User Name"
      assert props.validator == validator
      assert props.placeholder == "Type here"
    end
  end

  describe "init/1" do
    test "initializes state from props" do
      props = Line.new(prompt: "Enter: ", value: "test", label: "Label")
      {:ok, state} = Line.init(props)

      assert %Line{} = state
      assert state.prompt == "Enter: "
      assert state.value == "test"
      assert state.label == "Label"
      assert state.error == nil
    end

    test "initializes with validator" do
      validator = fn _x -> :ok end
      props = Line.new(validator: validator)
      {:ok, state} = Line.init(props)

      assert state.validator == validator
    end
  end

  describe "get_value/1" do
    test "returns current value" do
      {:ok, state} = Line.init(Line.new(value: "hello"))

      assert Line.get_value(state) == "hello"
    end

    test "returns empty string for new state" do
      {:ok, state} = Line.init(Line.new())

      assert Line.get_value(state) == ""
    end
  end

  describe "set_value/2" do
    test "sets new value" do
      {:ok, state} = Line.init(Line.new())
      state = Line.set_value(state, "new value")

      assert Line.get_value(state) == "new value"
    end

    test "clears error when setting value" do
      {:ok, state} = Line.init(Line.new())
      state = %{state | error: "some error"}
      state = Line.set_value(state, "new value")

      assert state.error == nil
    end
  end

  describe "clear/1" do
    test "clears value" do
      {:ok, state} = Line.init(Line.new(value: "existing"))
      state = Line.clear(state)

      assert Line.get_value(state) == ""
    end

    test "clears error" do
      {:ok, state} = Line.init(Line.new())
      state = %{state | error: "some error"}
      state = Line.clear(state)

      assert state.error == nil
    end
  end

  describe "error handling" do
    test "get_error returns nil when no error" do
      {:ok, state} = Line.init(Line.new())

      assert Line.get_error(state) == nil
    end

    test "get_error returns error message" do
      {:ok, state} = Line.init(Line.new())
      state = %{state | error: "validation failed"}

      assert Line.get_error(state) == "validation failed"
    end

    test "has_error? returns false when no error" do
      {:ok, state} = Line.init(Line.new())

      refute Line.has_error?(state)
    end

    test "has_error? returns true when error exists" do
      {:ok, state} = Line.init(Line.new())
      state = %{state | error: "error"}

      assert Line.has_error?(state)
    end

    test "clear_error removes error" do
      {:ok, state} = Line.init(Line.new())
      state = %{state | error: "error"}
      state = Line.clear_error(state)

      refute Line.has_error?(state)
    end
  end

  describe "accessors" do
    test "get_label returns label" do
      {:ok, state} = Line.init(Line.new(label: "My Label"))

      assert Line.get_label(state) == "My Label"
    end

    test "get_label returns nil when no label" do
      {:ok, state} = Line.init(Line.new())

      assert Line.get_label(state) == nil
    end

    test "get_prompt returns prompt" do
      {:ok, state} = Line.init(Line.new(prompt: ">>> "))

      assert Line.get_prompt(state) == ">>> "
    end

    test "get_placeholder returns placeholder" do
      {:ok, state} = Line.init(Line.new(placeholder: "Type here"))

      assert Line.get_placeholder(state) == "Type here"
    end
  end

  describe "read/1 without validator" do
    test "reads input and updates value" do
      {:ok, state} = Line.init(Line.new(prompt: "Name: "))

      capture_io([input: "John Doe\n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "John Doe", new_state}}
      assert new_state.value == "John Doe"
      assert new_state.error == nil
    end

    test "handles empty input" do
      {:ok, state} = Line.init(Line.new(prompt: "> "))

      capture_io([input: "\n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "", new_state}}
      assert new_state.value == ""
    end

    test "preserves whitespace in input" do
      {:ok, state} = Line.init(Line.new())

      capture_io([input: "  spaced  \n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "  spaced  ", _new_state}}
    end
  end

  describe "read/1 with validator" do
    test "returns ok when validation passes" do
      validator = fn input ->
        if String.length(input) >= 3, do: :ok, else: {:error, "too short"}
      end

      {:ok, state} = Line.init(Line.new(validator: validator))

      capture_io([input: "valid\n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "valid", new_state}}
      assert new_state.error == nil
    end

    test "returns error when validation fails" do
      validator = fn input ->
        if String.length(input) >= 3, do: :ok, else: {:error, "too short"}
      end

      {:ok, state} = Line.init(Line.new(validator: validator))

      capture_io([input: "ab\n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:error, "too short", new_state}}
      assert new_state.error == "too short"
    end

    test "transforms value when validator returns {:ok, transformed}" do
      validator = fn input ->
        case Integer.parse(input) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "not a number"}
        end
      end

      {:ok, state} = Line.init(Line.new(validator: validator))

      capture_io([input: "42\n", capture_prompt: false], fn ->
        result = Line.read(state)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, 42, _new_state}}
    end
  end

  describe "type specifications" do
    test "state is correct struct type" do
      {:ok, state} = Line.init(Line.new())

      assert %Line{} = state
    end

    test "module defines expected types" do
      # Verify module loads and has expected structure
      assert Code.ensure_loaded?(Line)
    end
  end

  describe "documentation" do
    test "module has documentation" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Line)

      assert is_binary(moduledoc)
      assert String.length(moduledoc) > 0
    end

    test "moduledoc explains shell line editing" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Line)

      assert String.contains?(moduledoc, "shell")
      assert String.contains?(moduledoc, "line editing")
    end

    test "moduledoc compares to standard TextInput" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Line)

      assert String.contains?(moduledoc, "TextInput")
    end

    test "moduledoc mentions LineReader" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Line)

      assert String.contains?(moduledoc, "LineReader")
    end
  end

  describe "render/1" do
    alias TermUI.Component.RenderNode

    test "renders just prompt and value when no label or error" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", value: "hello"))

      node = Line.render(state)

      assert %RenderNode{type: :text, content: "> hello"} = node
    end

    test "renders empty prompt and value" do
      {:ok, state} = Line.init(Line.new(prompt: "", value: ""))

      node = Line.render(state)

      assert %RenderNode{type: :text, content: ""} = node
    end

    test "renders with label on separate line" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", value: "test", label: "Name"))

      node = Line.render(state)

      # Should be a vertical stack with label and input line
      assert %RenderNode{type: :stack, direction: :vertical, children: children} = node
      assert length(children) == 2

      [label_node, input_node] = children
      assert %RenderNode{type: :text, content: "Name"} = label_node
      assert %RenderNode{type: :text, content: "> test"} = input_node
    end

    test "renders placeholder when value is empty" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", placeholder: "Type here"))

      node = Line.render(state)

      # Should be a horizontal stack with prompt and styled placeholder
      assert %RenderNode{type: :stack, direction: :horizontal, children: children} = node
      assert length(children) == 2

      [prompt_node, placeholder_node] = children
      assert %RenderNode{type: :text, content: "> "} = prompt_node
      assert %RenderNode{type: :text, content: "Type here"} = placeholder_node
      assert placeholder_node.style.fg == :bright_black
    end

    test "renders value instead of placeholder when value exists" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", value: "actual", placeholder: "Type here"))

      node = Line.render(state)

      # Value takes precedence over placeholder
      assert %RenderNode{type: :text, content: "> actual"} = node
    end

    test "renders error below input" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", value: "bad"))
      state = %{state | error: "Invalid input"}

      node = Line.render(state)

      # Should be a vertical stack with input line and error
      assert %RenderNode{type: :stack, direction: :vertical, children: children} = node
      assert length(children) == 2

      [input_node, error_node] = children
      assert %RenderNode{type: :text, content: "> bad"} = input_node
      assert %RenderNode{type: :text, content: "Invalid input"} = error_node
      assert error_node.style.fg == :red
    end

    test "renders label, input, and error all together" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", value: "x", label: "Input"))
      state = %{state | error: "Too short"}

      node = Line.render(state)

      # Should be a vertical stack with all three components
      assert %RenderNode{type: :stack, direction: :vertical, children: children} = node
      assert length(children) == 3

      [label_node, input_node, error_node] = children
      assert %RenderNode{type: :text, content: "Input"} = label_node
      assert %RenderNode{type: :text, content: "> x"} = input_node
      assert %RenderNode{type: :text, content: "Too short"} = error_node
    end

    test "renders label with placeholder and error" do
      {:ok, state} = Line.init(Line.new(prompt: "> ", label: "Name", placeholder: "Enter name"))
      state = %{state | error: "Required"}

      node = Line.render(state)

      assert %RenderNode{type: :stack, direction: :vertical, children: children} = node
      assert length(children) == 3

      [label_node, input_node, error_node] = children
      assert %RenderNode{type: :text, content: "Name"} = label_node
      # Input should be horizontal stack with prompt and placeholder
      assert %RenderNode{type: :stack, direction: :horizontal} = input_node
      assert %RenderNode{type: :text, content: "Required"} = error_node
    end
  end
end
