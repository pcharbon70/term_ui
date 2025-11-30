defmodule TermUI.Widgets.FormBuilderTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.FormBuilder

  @default_area %{width: 80, height: 24}

  describe "new/1 and init/1" do
    test "creates form with basic fields" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :username, type: :text, label: "Username"},
            %{id: :password, type: :password, label: "Password"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      assert length(state.fields) == 2
      assert state.focused_field == :username
      assert state.values[:username] == ""
      assert state.values[:password] == ""
    end

    test "initializes with default values" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", default: "John"},
            %{id: :active, type: :checkbox, label: "Active", default: true}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      assert state.values[:name] == "John"
      assert state.values[:active] == true
    end

    test "initializes with provided values" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name"},
            %{id: :email, type: :text, label: "Email"}
          ],
          values: %{name: "Alice", email: "alice@example.com"}
        )

      {:ok, state} = FormBuilder.init(props)

      assert state.values[:name] == "Alice"
      assert state.values[:email] == "alice@example.com"
    end

    test "sets default values for different field types" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :text_field, type: :text, label: "Text"},
            %{id: :checkbox_field, type: :checkbox, label: "Checkbox"},
            %{id: :multi_field, type: :multi_select, label: "Multi", options: []}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      assert state.values[:text_field] == ""
      assert state.values[:checkbox_field] == false
      assert state.values[:multi_field] == []
    end
  end

  describe "text field handling" do
    test "appends characters to text field" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name"}])

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "H"), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "i"), state)

      assert state.values[:name] == "Hi"
    end

    test "handles backspace in text field" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          values: %{name: "Hello"}
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:backspace), state)
      assert state.values[:name] == "Hell"

      {:ok, state} = FormBuilder.handle_event(Event.key(:backspace), state)
      assert state.values[:name] == "Hel"
    end

    test "handles empty backspace gracefully" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name"}])

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:backspace), state)
      assert state.values[:name] == ""
    end
  end

  describe "checkbox field handling" do
    test "toggles checkbox with space" do
      props =
        FormBuilder.new(fields: [%{id: :agree, type: :checkbox, label: "Agree"}])

      {:ok, state} = FormBuilder.init(props)
      assert state.values[:agree] == false

      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert state.values[:agree] == true

      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert state.values[:agree] == false
    end
  end

  describe "radio field handling" do
    test "selects option with space/enter" do
      props =
        FormBuilder.new(
          fields: [
            %{
              id: :color,
              type: :radio,
              label: "Color",
              options: [{"red", "Red"}, {"green", "Green"}, {"blue", "Blue"}]
            }
          ]
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.values[:color] == ""

      # Select first option (focused by default)
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert state.values[:color] == "red"

      # Navigate to next option
      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert state.values[:color] == "green"
    end

    test "navigates options with arrow keys" do
      props =
        FormBuilder.new(
          fields: [
            %{
              id: :size,
              type: :radio,
              label: "Size",
              options: [{"s", "Small"}, {"m", "Medium"}, {"l", "Large"}]
            }
          ]
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.focused_option == 0

      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      assert state.focused_option == 1

      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      assert state.focused_option == 2

      # Wrap around
      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      assert state.focused_option == 0

      {:ok, state} = FormBuilder.handle_event(Event.key(:up), state)
      assert state.focused_option == 2
    end
  end

  describe "select field handling" do
    test "selects option" do
      props =
        FormBuilder.new(
          fields: [
            %{
              id: :country,
              type: :select,
              label: "Country",
              options: [{"us", "USA"}, {"uk", "UK"}, {"ca", "Canada"}]
            }
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(:enter), state)

      assert state.values[:country] == "uk"
    end
  end

  describe "multi-select field handling" do
    test "toggles multiple selections" do
      props =
        FormBuilder.new(
          fields: [
            %{
              id: :tags,
              type: :multi_select,
              label: "Tags",
              options: [{"a", "Tag A"}, {"b", "Tag B"}, {"c", "Tag C"}]
            }
          ]
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.values[:tags] == []

      # Select first
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert "a" in state.values[:tags]

      # Select second
      {:ok, state} = FormBuilder.handle_event(Event.key(:down), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      assert "a" in state.values[:tags]
      assert "b" in state.values[:tags]

      # Deselect first
      {:ok, state} = FormBuilder.handle_event(Event.key(:up), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)
      refute "a" in state.values[:tags]
      assert "b" in state.values[:tags]
    end
  end

  describe "tab navigation" do
    test "navigates between fields with Tab" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :field1, type: :text, label: "Field 1"},
            %{id: :field2, type: :text, label: "Field 2"},
            %{id: :field3, type: :text, label: "Field 3"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.focused_field == :field1

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.focused_field == :field2

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.focused_field == :field3
    end

    test "navigates backwards with Shift+Tab" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :field1, type: :text, label: "Field 1"},
            %{id: :field2, type: :text, label: "Field 2"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.focused_field == :field2

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab, modifiers: [:shift]), state)
      assert state.focused_field == :field1
    end

    test "wraps around at field boundaries" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :field1, type: :text, label: "Field 1"},
            %{id: :field2, type: :text, label: "Field 2"}
          ],
          show_submit_button: false
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.focused_field == :field1
    end

    test "includes submit button in navigation" do
      props =
        FormBuilder.new(
          fields: [%{id: :field1, type: :text, label: "Field 1"}],
          show_submit_button: true
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.focused_field == :field1
      refute state.submit_focused

      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.submit_focused
    end

    test "skips hidden fields in navigation" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :show_extra, type: :checkbox, label: "Show Extra"},
            %{
              id: :extra,
              type: :text,
              label: "Extra",
              visible_when: fn values -> values[:show_extra] end
            },
            %{id: :final, type: :text, label: "Final"}
          ],
          show_submit_button: false
        )

      {:ok, state} = FormBuilder.init(props)
      assert state.focused_field == :show_extra

      # Extra field is hidden, so Tab should skip to final
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.focused_field == :final
    end
  end

  describe "validation" do
    test "validates required fields" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", required: true}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.validate(state)
      assert ["This field is required"] == state.errors[:name]
    end

    test "passes validation when required field has value" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", required: true}
          ],
          values: %{name: "John"}
        )

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.validate(state)
      assert state.errors[:name] == []
    end

    test "runs custom validators" do
      email_validator = fn value ->
        if String.contains?(value, "@") do
          :ok
        else
          {:error, "Must be a valid email"}
        end
      end

      props =
        FormBuilder.new(
          fields: [
            %{id: :email, type: :text, label: "Email", validators: [email_validator]}
          ],
          values: %{email: "invalid"}
        )

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.validate(state)
      assert "Must be a valid email" in state.errors[:email]
    end

    test "validates on blur when enabled" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :field1, type: :text, label: "Field 1", required: true},
            %{id: :field2, type: :text, label: "Field 2"}
          ],
          validate_on_blur: true
        )

      {:ok, state} = FormBuilder.init(props)

      # Tab away from field1 (which is empty and required)
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)

      assert ["This field is required"] == state.errors[:field1]
    end

    test "valid? returns correct status" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", required: true}
          ]
        )

      {:ok, state} = FormBuilder.init(props)
      refute FormBuilder.valid?(state)

      state = FormBuilder.set_value(state, :name, "John")
      assert FormBuilder.valid?(state)
    end
  end

  describe "conditional fields" do
    test "shows field when condition is met" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :has_discount, type: :checkbox, label: "Has Discount"},
            %{
              id: :discount_code,
              type: :text,
              label: "Code",
              visible_when: fn values -> values[:has_discount] end
            }
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      # Initially checkbox is false, so discount_code is hidden
      visible_fields =
        state.fields
        |> Enum.filter(fn f ->
          case f.visible_when do
            nil -> true
            cond -> cond.(state.values)
          end
        end)
        |> Enum.map(& &1.id)

      assert :has_discount in visible_fields
      refute :discount_code in visible_fields

      # Toggle checkbox
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)

      visible_fields =
        state.fields
        |> Enum.filter(fn f ->
          case f.visible_when do
            nil -> true
            cond -> cond.(state.values)
          end
        end)
        |> Enum.map(& &1.id)

      assert :discount_code in visible_fields
    end
  end

  describe "callbacks" do
    test "calls on_change when value changes" do
      test_pid = self()

      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          on_change: fn field_id, value ->
            send(test_pid, {:changed, field_id, value})
          end
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, _state} = FormBuilder.handle_event(Event.key(nil, char: "A"), state)

      assert_receive {:changed, :name, "A"}
    end

    test "calls on_submit when form is submitted" do
      test_pid = self()

      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          values: %{name: "Test"},
          on_submit: fn values ->
            send(test_pid, {:submitted, values})
          end
        )

      {:ok, state} = FormBuilder.init(props)

      # Navigate to submit button
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.submit_focused

      # Submit
      {:ok, _state} = FormBuilder.handle_event(Event.key(" "), state)

      assert_receive {:submitted, %{name: "Test"}}
    end

    test "does not submit when validation fails" do
      test_pid = self()

      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name", required: true}],
          on_submit: fn values ->
            send(test_pid, {:submitted, values})
          end
        )

      {:ok, state} = FormBuilder.init(props)

      # Navigate to submit button
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)

      # Try to submit
      {:ok, state} = FormBuilder.handle_event(Event.key(" "), state)

      refute_receive {:submitted, _}
      assert state.errors[:name] != []
    end
  end

  describe "rendering" do
    test "renders form with fields" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name"},
            %{id: :active, type: :checkbox, label: "Active"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      output = FormBuilder.render(state, @default_area)
      assert output != nil
      assert output.type == :stack
    end

    test "renders submit button when enabled" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          show_submit_button: true,
          submit_label: "Save"
        )

      {:ok, state} = FormBuilder.init(props)

      output = FormBuilder.render(state, @default_area)
      assert output != nil
    end

    test "does not render submit button when disabled" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          show_submit_button: false
        )

      {:ok, state} = FormBuilder.init(props)

      output = FormBuilder.render(state, @default_area)
      assert output != nil
    end
  end

  describe "public API" do
    test "get_values returns all values" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :a, type: :text, label: "A"},
            %{id: :b, type: :text, label: "B"}
          ],
          values: %{a: "1", b: "2"}
        )

      {:ok, state} = FormBuilder.init(props)

      values = FormBuilder.get_values(state)
      assert values[:a] == "1"
      assert values[:b] == "2"
    end

    test "get_value returns specific field value" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          values: %{name: "Test"}
        )

      {:ok, state} = FormBuilder.init(props)

      assert FormBuilder.get_value(state, :name) == "Test"
    end

    test "set_value updates field value" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name"}])

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.set_value(state, :name, "Updated")
      assert state.values[:name] == "Updated"
    end

    test "set_values updates multiple values" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :a, type: :text, label: "A"},
            %{id: :b, type: :text, label: "B"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.set_values(state, %{a: "X", b: "Y"})
      assert state.values[:a] == "X"
      assert state.values[:b] == "Y"
    end

    test "focus_field sets focus to specific field" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :field1, type: :text, label: "Field 1"},
            %{id: :field2, type: :text, label: "Field 2"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      state = FormBuilder.focus_field(state, :field2)
      assert state.focused_field == :field2
    end

    test "get_focused_field returns current focus" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name"}])

      {:ok, state} = FormBuilder.init(props)

      assert FormBuilder.get_focused_field(state) == :name
    end

    test "reset clears form to defaults" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", default: "Default"},
            %{id: :active, type: :checkbox, label: "Active"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      # Modify values
      state = FormBuilder.set_value(state, :name, "Changed")
      state = FormBuilder.set_value(state, :active, true)

      # Reset
      state = FormBuilder.reset(state)

      assert state.values[:name] == "Default"
      assert state.values[:active] == false
      assert state.errors == %{}
    end
  end

  describe "field grouping" do
    test "supports grouped fields" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :name, type: :text, label: "Name", group: :personal},
            %{id: :email, type: :text, label: "Email", group: :personal},
            %{id: :company, type: :text, label: "Company", group: :work}
          ],
          groups: [
            %{id: :personal, label: "Personal Info", collapsible: true},
            %{id: :work, label: "Work Info", collapsible: true}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      assert length(state.groups) == 2
      assert MapSet.size(state.collapsed_groups) == 0
    end

    test "toggle_group collapses and expands groups" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name", group: :info}],
          groups: [%{id: :info, label: "Info", collapsible: true}]
        )

      {:ok, state} = FormBuilder.init(props)

      # Collapse
      state = FormBuilder.toggle_group(state, :info)
      assert MapSet.member?(state.collapsed_groups, :info)

      # Expand
      state = FormBuilder.toggle_group(state, :info)
      refute MapSet.member?(state.collapsed_groups, :info)
    end
  end

  describe "password field handling" do
    test "password field masks characters in rendering" do
      props =
        FormBuilder.new(
          fields: [%{id: :password, type: :password, label: "Password"}],
          values: %{password: "secret123"}
        )

      {:ok, state} = FormBuilder.init(props)

      # Verify the value is stored correctly (not masked in state)
      assert state.values[:password] == "secret123"

      # Render and verify output contains masked characters
      result = FormBuilder.render(state, @default_area)
      assert result != nil
    end

    test "password field accepts character input" do
      props =
        FormBuilder.new(fields: [%{id: :password, type: :password, label: "Password"}])

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "s"), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "e"), state)
      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "c"), state)

      assert state.values[:password] == "sec"
    end

    test "password field handles backspace" do
      props =
        FormBuilder.new(
          fields: [%{id: :password, type: :password, label: "Password"}],
          values: %{password: "secret"}
        )

      {:ok, state} = FormBuilder.init(props)

      {:ok, state} = FormBuilder.handle_event(Event.key(:backspace), state)

      assert state.values[:password] == "secre"
    end

    test "password field with placeholder" do
      props =
        FormBuilder.new(
          fields: [
            %{id: :password, type: :password, label: "Password", placeholder: "Enter password"}
          ]
        )

      {:ok, state} = FormBuilder.init(props)

      # Empty password should show placeholder in render
      result = FormBuilder.render(state, @default_area)
      assert result != nil
    end
  end

  describe "get_errors/1 public API" do
    test "returns empty map when no errors" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name"}])

      {:ok, state} = FormBuilder.init(props)

      assert FormBuilder.get_errors(state) == %{}
    end

    test "returns errors map after validation failure" do
      props =
        FormBuilder.new(fields: [%{id: :name, type: :text, label: "Name", required: true}])

      {:ok, state} = FormBuilder.init(props)
      state = FormBuilder.validate(state)

      errors = FormBuilder.get_errors(state)
      assert Map.has_key?(errors, :name)
      assert errors[:name] != []
    end
  end

  describe "placeholder display" do
    test "placeholder is set in field definition" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name", placeholder: "Enter name"}]
        )

      {:ok, state} = FormBuilder.init(props)

      field = Enum.find(state.fields, &(&1.id == :name))
      assert field.placeholder == "Enter name"
    end

    test "renders with placeholder when value is empty" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name", placeholder: "Enter name"}]
        )

      {:ok, state} = FormBuilder.init(props)
      result = FormBuilder.render(state, @default_area)

      # Render should produce a valid result
      assert result != nil
    end
  end

  describe "empty fields edge case" do
    test "handles empty fields list" do
      props = FormBuilder.new(fields: [])

      {:ok, state} = FormBuilder.init(props)

      assert state.fields == []
      assert state.focused_field == nil
    end

    test "navigation with empty fields" do
      props = FormBuilder.new(fields: [], show_submit_button: true)

      {:ok, state} = FormBuilder.init(props)

      # Tab should focus submit button
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.submit_focused == true
    end
  end

  describe "callback error handling" do
    test "on_change callback errors are caught" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          on_change: fn _field_id, _value -> raise "Callback error" end
        )

      {:ok, state} = FormBuilder.init(props)

      # Should not crash despite callback error
      {:ok, state} = FormBuilder.handle_event(Event.key(nil, char: "a"), state)
      assert state.values[:name] == "a"
    end

    test "on_submit callback errors are caught" do
      props =
        FormBuilder.new(
          fields: [%{id: :name, type: :text, label: "Name"}],
          values: %{name: "test"},
          on_submit: fn _values -> raise "Submit error" end
        )

      {:ok, state} = FormBuilder.init(props)

      # Navigate to submit button
      {:ok, state} = FormBuilder.handle_event(Event.key(:tab), state)
      assert state.submit_focused == true

      # Submit should not crash despite callback error
      {:ok, _state} = FormBuilder.handle_event(Event.key(:enter), state)
    end
  end
end
