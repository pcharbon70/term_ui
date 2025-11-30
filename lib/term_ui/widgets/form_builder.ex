defmodule TermUI.Widgets.FormBuilder do
  @moduledoc """
  FormBuilder widget for structured forms with multiple field types.

  Provides comprehensive form handling with validation, navigation,
  conditional fields, and field grouping.

  ## Usage

      FormBuilder.new(
        fields: [
          %{id: :username, type: :text, label: "Username", required: true},
          %{id: :password, type: :password, label: "Password", required: true},
          %{id: :remember, type: :checkbox, label: "Remember me"},
          %{id: :role, type: :select, label: "Role",
            options: [{"admin", "Admin"}, {"user", "User"}]}
        ],
        on_submit: fn values -> handle_submit(values) end,
        on_change: fn field_id, value -> handle_change(field_id, value) end
      )

  ## Field Types

  - `:text` - Single line text input
  - `:password` - Masked text input
  - `:checkbox` - Boolean toggle
  - `:radio` - Single selection from options
  - `:select` - Dropdown single selection
  - `:multi_select` - Multiple selection from options

  ## Keyboard Navigation

  - Tab/Shift+Tab: Move between fields
  - Up/Down: Navigate options (radio/select/multi_select)
  - Space: Toggle checkbox, select option
  - Enter: Submit form (when on submit button)
  - Escape: Cancel editing
  """

  use TermUI.StatefulComponent

  alias TermUI.Event
  alias TermUI.Widgets.WidgetHelpers, as: Helpers

  @type field_type :: :text | :password | :checkbox | :radio | :select | :multi_select

  @type field_def :: %{
          id: atom(),
          type: field_type(),
          label: String.t(),
          options: [{term(), String.t()}] | nil,
          required: boolean(),
          validators: [(term() -> :ok | {:error, String.t()})],
          visible_when: (map() -> boolean()) | nil,
          group: atom() | nil,
          placeholder: String.t() | nil,
          default: term() | nil
        }

  @type group_def :: %{
          id: atom(),
          label: String.t(),
          collapsible: boolean()
        }

  @doc """
  Creates new FormBuilder widget props.

  ## Options

  - `:fields` - List of field definitions (required)
  - `:groups` - List of group definitions for organizing fields
  - `:on_submit` - Callback when form is submitted
  - `:on_change` - Callback when any field value changes
  - `:values` - Initial field values
  - `:show_submit_button` - Whether to show submit button (default: true)
  - `:submit_label` - Label for submit button (default: "Submit")
  - `:validate_on_blur` - Validate when field loses focus (default: true)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    fields = Keyword.fetch!(opts, :fields)

    %{
      fields: normalize_fields(fields),
      groups: Keyword.get(opts, :groups, []),
      on_submit: Keyword.get(opts, :on_submit),
      on_change: Keyword.get(opts, :on_change),
      initial_values: Keyword.get(opts, :values, %{}),
      show_submit_button: Keyword.get(opts, :show_submit_button, true),
      submit_label: Keyword.get(opts, :submit_label, "Submit"),
      validate_on_blur: Keyword.get(opts, :validate_on_blur, true),
      label_width: Keyword.get(opts, :label_width, 15),
      field_width: Keyword.get(opts, :field_width, 30)
    }
  end

  defp normalize_fields(fields) do
    Enum.map(fields, fn field ->
      Map.merge(
        %{
          required: false,
          validators: [],
          visible_when: nil,
          group: nil,
          placeholder: nil,
          default: nil,
          options: nil
        },
        field
      )
    end)
  end

  @impl true
  def init(props) do
    # Initialize values with defaults
    initial_values =
      Enum.reduce(props.fields, props.initial_values, fn field, acc ->
        if Map.has_key?(acc, field.id) do
          acc
        else
          default_value = field.default || get_default_for_type(field.type)
          Map.put(acc, field.id, default_value)
        end
      end)

    # Get first visible field for focus
    first_field = get_first_visible_field(props.fields, initial_values)

    state = %{
      fields: props.fields,
      groups: props.groups,
      values: initial_values,
      errors: %{},
      focused_field: first_field,
      focused_option: 0,
      collapsed_groups: MapSet.new(),
      on_submit: props.on_submit,
      on_change: props.on_change,
      show_submit_button: props.show_submit_button,
      submit_label: props.submit_label,
      validate_on_blur: props.validate_on_blur,
      label_width: props.label_width,
      field_width: props.field_width,
      editing_text: nil,
      submit_focused: false
    }

    {:ok, state}
  end

  @impl true
  def update(new_props, state) do
    # Update fields and groups from new props
    state =
      state
      |> Map.put(:fields, normalize_fields(new_props.fields))
      |> Map.put(:groups, new_props.groups)
      |> Map.put(:show_submit_button, new_props.show_submit_button)
      |> Map.put(:submit_label, new_props.submit_label)
      |> Map.put(:label_width, new_props.label_width)
      |> Map.put(:field_width, new_props.field_width)

    # Update values with any new initial values, keeping existing values
    initial_values = new_props.initial_values || %{}
    values = Map.merge(initial_values, state.values)
    state = %{state | values: values}

    {:ok, state}
  end

  defp get_default_for_type(:checkbox), do: false
  defp get_default_for_type(:multi_select), do: []
  defp get_default_for_type(_), do: ""

  defp get_first_visible_field(fields, values) do
    fields
    |> Enum.filter(&field_visible?(&1, values))
    |> List.first()
    |> case do
      nil -> nil
      field -> field.id
    end
  end

  @impl true
  def handle_event(%Event.Key{key: :tab, modifiers: modifiers}, state) do
    direction = if :shift in modifiers, do: -1, else: 1
    state = navigate_field(state, direction)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :up}, state) do
    field = get_field(state, state.focused_field)

    cond do
      field && field.type in [:radio, :select, :multi_select] ->
        state = navigate_option(state, -1)
        {:ok, state}

      true ->
        state = navigate_field(state, -1)
        {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :down}, state) do
    field = get_field(state, state.focused_field)

    cond do
      field && field.type in [:radio, :select, :multi_select] ->
        state = navigate_option(state, 1)
        {:ok, state}

      true ->
        state = navigate_field(state, 1)
        {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: " "}, state) do
    field = get_field(state, state.focused_field)

    cond do
      state.submit_focused ->
        submit_form(state)

      field && field.type == :checkbox ->
        state = toggle_checkbox(state, field.id)
        {:ok, state}

      field && field.type in [:radio, :select] ->
        state = select_current_option(state)
        {:ok, state}

      field && field.type == :multi_select ->
        state = toggle_multi_select_option(state)
        {:ok, state}

      field && field.type in [:text, :password] ->
        state = append_char(state, " ")
        {:ok, state}

      true ->
        {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    if state.submit_focused do
      submit_form(state)
    else
      field = get_field(state, state.focused_field)

      cond do
        field && field.type in [:radio, :select] ->
          state = select_current_option(state)
          {:ok, state}

        true ->
          # Move to next field or submit
          state = navigate_field(state, 1)
          {:ok, state}
      end
    end
  end

  def handle_event(%Event.Key{key: :backspace}, state) do
    field = get_field(state, state.focused_field)

    if field && field.type in [:text, :password] do
      state = delete_char(state)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{char: char}, state) when is_binary(char) and char != "" do
    field = get_field(state, state.focused_field)

    if field && field.type in [:text, :password] do
      state = append_char(state, char)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :escape}, state) do
    # Cancel editing or blur focus
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    # Group fields by their group
    grouped_fields = group_fields(state)

    # Render each group
    rendered_groups =
      Enum.flat_map(grouped_fields, fn {group_id, fields} ->
        render_group(state, group_id, fields, area)
      end)

    # Add submit button if enabled
    elements =
      if state.show_submit_button do
        rendered_groups ++ [render_submit_button(state)]
      else
        rendered_groups
      end

    stack(:vertical, elements)
  end

  # Navigation helpers

  defp navigate_field(state, direction) do
    visible_fields =
      state.fields
      |> Enum.filter(&field_visible?(&1, state.values))
      |> Enum.map(& &1.id)

    all_focusable =
      if state.show_submit_button do
        visible_fields ++ [:__submit__]
      else
        visible_fields
      end

    current =
      if state.submit_focused do
        :__submit__
      else
        state.focused_field
      end

    current_idx = Enum.find_index(all_focusable, &(&1 == current)) || 0
    new_idx = rem(current_idx + direction + length(all_focusable), length(all_focusable))
    new_focus = Enum.at(all_focusable, new_idx)

    # Validate on blur if enabled
    state =
      if state.validate_on_blur && state.focused_field && !state.submit_focused do
        validate_field(state, state.focused_field)
      else
        state
      end

    if new_focus == :__submit__ do
      %{state | submit_focused: true, focused_option: 0}
    else
      # Reset focused_option to 0 when navigating to a new field
      %{state | focused_field: new_focus, submit_focused: false, focused_option: 0}
    end
  end

  defp navigate_option(state, direction) do
    field = get_field(state, state.focused_field)

    if field && field.options do
      option_count = length(field.options)
      new_idx = rem(state.focused_option + direction + option_count, option_count)
      %{state | focused_option: new_idx}
    else
      state
    end
  end

  # Field operations

  defp toggle_checkbox(state, field_id) do
    current = Map.get(state.values, field_id, false)
    update_value(state, field_id, !current)
  end

  defp select_current_option(state) do
    field = get_field(state, state.focused_field)

    if field && field.options do
      {value, _label} = Enum.at(field.options, state.focused_option, {"", ""})
      update_value(state, field.id, value)
    else
      state
    end
  end

  defp toggle_multi_select_option(state) do
    field = get_field(state, state.focused_field)

    if field && field.options do
      {value, _label} = Enum.at(field.options, state.focused_option, {"", ""})
      current = Map.get(state.values, field.id, [])

      new_value =
        if value in current do
          List.delete(current, value)
        else
          [value | current]
        end

      update_value(state, field.id, new_value)
    else
      state
    end
  end

  defp append_char(state, char) do
    current = Map.get(state.values, state.focused_field, "")
    update_value(state, state.focused_field, current <> char)
  end

  defp delete_char(state) do
    current = Map.get(state.values, state.focused_field, "")

    if String.length(current) > 0 do
      new_value = String.slice(current, 0..-2//1)
      update_value(state, state.focused_field, new_value)
    else
      state
    end
  end

  defp update_value(state, field_id, value) do
    state = %{state | values: Map.put(state.values, field_id, value)}

    # Call on_change callback with error handling
    if state.on_change do
      try do
        state.on_change.(field_id, value)
      rescue
        e ->
          require Logger

          Logger.error(
            "FormBuilder on_change callback error for field #{field_id}: #{inspect(e)}"
          )
      end
    end

    state
  end

  # Validation

  defp validate_field(state, field_id) do
    field = get_field(state, field_id)
    value = Map.get(state.values, field_id)

    errors = run_validators(field, value)
    %{state | errors: Map.put(state.errors, field_id, errors)}
  end

  defp validate_all(state) do
    errors =
      state.fields
      |> Enum.filter(&field_visible?(&1, state.values))
      |> Enum.reduce(%{}, fn field, acc ->
        value = Map.get(state.values, field.id)
        field_errors = run_validators(field, value)
        Map.put(acc, field.id, field_errors)
      end)

    %{state | errors: errors}
  end

  defp run_validators(field, value) do
    errors = []

    # Required validation
    errors =
      if field.required && empty_value?(value) do
        ["This field is required" | errors]
      else
        errors
      end

    # Custom validators
    Enum.reduce(field.validators, errors, fn validator, acc ->
      case validator.(value) do
        :ok -> acc
        {:error, msg} -> [msg | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp empty_value?(""), do: true
  defp empty_value?(nil), do: true
  defp empty_value?([]), do: true
  defp empty_value?(false), do: false
  defp empty_value?(_), do: false

  defp has_errors?(state) do
    Enum.any?(state.errors, fn {_field_id, errors} -> errors != [] end)
  end

  # Submit

  defp submit_form(state) do
    state = validate_all(state)

    if has_errors?(state) do
      {:ok, state}
    else
      # Call on_submit callback with error handling
      if state.on_submit do
        try do
          state.on_submit.(state.values)
        rescue
          e ->
            require Logger
            Logger.error("FormBuilder on_submit callback error: #{inspect(e)}")
        end
      end

      {:ok, state}
    end
  end

  # Visibility

  defp field_visible?(field, values) do
    case field.visible_when do
      nil -> true
      condition when is_function(condition, 1) -> condition.(values)
      _ -> true
    end
  end

  # Grouping

  defp group_fields(state) do
    # First, ungrouped fields
    ungrouped =
      state.fields
      |> Enum.filter(&(is_nil(&1.group) && field_visible?(&1, state.values)))

    # Then, grouped fields
    grouped =
      state.groups
      |> Enum.map(fn group ->
        fields =
          state.fields
          |> Enum.filter(&(&1.group == group.id && field_visible?(&1, state.values)))

        {group, fields}
      end)
      |> Enum.filter(fn {_group, fields} -> fields != [] end)

    [{nil, ungrouped} | grouped]
    |> Enum.filter(fn {_group, fields} -> fields != [] end)
  end

  # Rendering

  defp render_group(state, nil, fields, _area) do
    # Ungrouped fields - just render them
    Enum.flat_map(fields, &render_field(state, &1))
  end

  defp render_group(state, group, fields, _area) when is_map(group) do
    collapsed = MapSet.member?(state.collapsed_groups, group.id)

    header = render_group_header(group, collapsed)

    if collapsed do
      [header]
    else
      body = Enum.flat_map(fields, &render_field(state, &1))
      [header | body]
    end
  end

  defp render_group_header(group, collapsed) do
    indicator = if collapsed, do: "▶", else: "▼"
    text("#{indicator} #{group.label}")
  end

  defp render_field(state, field) do
    focused = state.focused_field == field.id && !state.submit_focused
    value = Map.get(state.values, field.id)
    errors = Map.get(state.errors, field.id, [])

    label_width = state.label_width
    _field_width = state.field_width

    # Build label
    label_text = Helpers.pad_and_truncate(field.label, label_width)

    required_marker = if field.required, do: "*", else: " "
    label = "#{label_text}#{required_marker} "

    # Build field content based on type
    field_content = render_field_content(field, value, state, focused)

    # Combine into row
    row =
      stack(:horizontal, [
        text(Helpers.focus_indicator(focused)),
        text(label),
        field_content
      ])

    # Add error messages
    if errors != [] do
      error_rows =
        Enum.map(errors, fn err ->
          padding = String.duplicate(" ", label_width + 5)
          styled(text("#{padding}! #{err}"), Style.new(fg: :red))
        end)

      [row | error_rows]
    else
      [row]
    end
  end

  defp render_field_content(field, value, state, focused) do
    case field.type do
      :text ->
        render_text_field(field, value, state.field_width, focused)

      :password ->
        render_password_field(field, value, state.field_width, focused)

      :checkbox ->
        render_checkbox_field(value, focused)

      :radio ->
        render_radio_field(field, value, state.focused_option, focused)

      :select ->
        render_select_field(field, value, state.focused_option, focused)

      :multi_select ->
        render_multi_select_field(field, value, state.focused_option, focused)
    end
  end

  defp render_text_field(field, value, width, focused) do
    display_value =
      if value == "" && field.placeholder do
        field.placeholder
      else
        value
      end

    content = "[#{Helpers.pad_and_truncate(display_value, width)}]"
    Helpers.text_focused(content, focused)
  end

  defp render_password_field(field, value, width, focused) do
    masked = String.duplicate("*", String.length(value))

    display_value =
      if masked == "" && field.placeholder do
        field.placeholder
      else
        masked
      end

    content = "[#{Helpers.pad_and_truncate(display_value, width)}]"
    Helpers.text_focused(content, focused)
  end

  defp render_checkbox_field(value, focused) do
    checkbox = if value, do: "[x]", else: "[ ]"
    Helpers.text_focused(checkbox, focused)
  end

  defp render_radio_field(field, selected_value, focused_option, focused) do
    options =
      field.options
      |> Enum.with_index()
      |> Enum.map(fn {{value, label}, idx} ->
        selected = value == selected_value
        option_focused = focused && idx == focused_option

        indicator = if selected, do: "(o)", else: "( )"
        content = "#{indicator} #{label}"

        Helpers.text_focused(content, option_focused)
      end)

    stack(:horizontal, Enum.intersperse(options, text("  ")))
  end

  defp render_select_field(field, selected_value, focused_option, focused) do
    # Show selected value with dropdown indicator
    selected_label =
      case Enum.find(field.options, fn {v, _l} -> v == selected_value end) do
        {_, label} -> label
        nil -> "(select)"
      end

    if focused do
      # Show expanded options
      options =
        field.options
        |> Enum.with_index()
        |> Enum.map(fn {{value, label}, idx} ->
          option_focused = idx == focused_option
          selected = value == selected_value

          prefix = if selected, do: "* ", else: "  "
          content = "#{prefix}#{label}"

          Helpers.text_focused(content, option_focused)
        end)

      stack(:vertical, options)
    else
      text("[#{selected_label} v]")
    end
  end

  defp render_multi_select_field(field, selected_values, focused_option, focused) do
    selected_values = selected_values || []

    options =
      field.options
      |> Enum.with_index()
      |> Enum.map(fn {{value, label}, idx} ->
        selected = value in selected_values
        option_focused = focused && idx == focused_option

        checkbox = if selected, do: "[x]", else: "[ ]"
        content = "#{checkbox} #{label}"

        Helpers.text_focused(content, option_focused)
      end)

    stack(:vertical, options)
  end

  defp render_submit_button(state) do
    label = "[ #{state.submit_label} ]"
    content = Helpers.text_focused(label, state.submit_focused)
    padding = String.duplicate(" ", state.label_width + 3)

    stack(:vertical, [
      text(""),
      stack(:horizontal, [text(padding), content])
    ])
  end

  # Helpers

  defp get_field(state, field_id) do
    Enum.find(state.fields, &(&1.id == field_id))
  end

  # Public API

  @doc """
  Gets the current form values.
  """
  @spec get_values(map()) :: map()
  def get_values(state) do
    state.values
  end

  @doc """
  Gets the value of a specific field.
  """
  @spec get_value(map(), atom()) :: term()
  def get_value(state, field_id) do
    Map.get(state.values, field_id)
  end

  @doc """
  Sets the value of a specific field.
  """
  @spec set_value(map(), atom(), term()) :: map()
  def set_value(state, field_id, value) do
    %{state | values: Map.put(state.values, field_id, value)}
  end

  @doc """
  Sets multiple field values at once.
  """
  @spec set_values(map(), map()) :: map()
  def set_values(state, values) do
    %{state | values: Map.merge(state.values, values)}
  end

  @doc """
  Gets all validation errors.
  """
  @spec get_errors(map()) :: map()
  def get_errors(state) do
    state.errors
  end

  @doc """
  Checks if the form has any validation errors.
  """
  @spec valid?(map()) :: boolean()
  def valid?(state) do
    !has_errors?(validate_all(state))
  end

  @doc """
  Validates all fields and returns updated state.
  """
  @spec validate(map()) :: map()
  def validate(state) do
    validate_all(state)
  end

  @doc """
  Focuses a specific field.
  """
  @spec focus_field(map(), atom()) :: map()
  def focus_field(state, field_id) do
    if Enum.any?(state.fields, &(&1.id == field_id)) do
      %{state | focused_field: field_id, submit_focused: false}
    else
      state
    end
  end

  @doc """
  Gets the currently focused field.
  """
  @spec get_focused_field(map()) :: atom() | nil
  def get_focused_field(state) do
    state.focused_field
  end

  @doc """
  Toggles a group's collapsed state.
  """
  @spec toggle_group(map(), atom()) :: map()
  def toggle_group(state, group_id) do
    if MapSet.member?(state.collapsed_groups, group_id) do
      %{state | collapsed_groups: MapSet.delete(state.collapsed_groups, group_id)}
    else
      %{state | collapsed_groups: MapSet.put(state.collapsed_groups, group_id)}
    end
  end

  @doc """
  Resets the form to initial values.
  """
  @spec reset(map()) :: map()
  def reset(state) do
    initial_values =
      Enum.reduce(state.fields, %{}, fn field, acc ->
        default_value = field.default || get_default_for_type(field.type)
        Map.put(acc, field.id, default_value)
      end)

    first_field = get_first_visible_field(state.fields, initial_values)

    %{
      state
      | values: initial_values,
        errors: %{},
        focused_field: first_field,
        submit_focused: false
    }
  end
end
