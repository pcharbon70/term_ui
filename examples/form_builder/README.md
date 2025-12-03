# FormBuilder Widget Example

This example demonstrates the FormBuilder widget for creating structured forms with multiple field types, validation, and conditional fields.

## Widget Overview

The FormBuilder widget provides comprehensive form handling with automatic layout, validation, and navigation. It's ideal for:

- Registration and login forms
- Settings and configuration panels
- Data entry interfaces
- Multi-step wizards
- Survey forms

**Key Features:**
- Multiple field types (text, password, checkbox, radio, select, multi-select)
- Built-in validation with custom validators
- Conditional field visibility
- Field grouping and organization
- Automatic keyboard navigation
- Required field indicators
- Error message display
- Submit button with validation

## Widget Options

The `FormBuilder.new/1` function accepts the following options:

- `:fields` (required) - List of field definitions
- `:groups` - List of group definitions for organizing fields
- `:on_submit` - Callback function `(values -> any)` when form is submitted
- `:on_change` - Callback function `(field_id, value -> any)` when any field value changes
- `:values` - Map of initial field values
- `:show_submit_button` - Whether to show submit button (default: true)
- `:submit_label` - Label for submit button (default: "Submit")
- `:validate_on_blur` - Validate when field loses focus (default: true)
- `:label_width` - Width for field labels (default: 15)
- `:field_width` - Width for field inputs (default: 30)

**Field Definition:**

Each field is a map with:
- `:id` (required) - Unique atom identifier
- `:type` (required) - Field type (see below)
- `:label` (required) - Display label
- `:required` - Boolean, whether field is required (default: false)
- `:validators` - List of validator functions
- `:visible_when` - Function `(values -> boolean)` for conditional visibility
- `:placeholder` - Placeholder text for text/password fields
- `:default` - Default value
- `:options` - List of `{value, label}` tuples for select/radio/multi-select

**Field Types:**
- `:text` - Single line text input
- `:password` - Masked text input
- `:checkbox` - Boolean toggle
- `:radio` - Single selection from options
- `:select` - Dropdown single selection
- `:multi_select` - Multiple selection from options

## Example Structure

```
form_builder/
├── lib/
│   └── form_builder/
│       └── app.ex          # Main application component
├── mix.exs                  # Project configuration
└── README.md               # This file
```

**app.ex** - Demonstrates comprehensive form features:
- Text and password fields with validation
- Checkbox with conditional field (email frequency)
- Radio buttons for options
- Select dropdown for country
- Multi-select for interests
- Custom validators (password strength, email format)
- Form submission with validation
- Display of submitted data

## Running the Example

```bash
# From the form_builder directory
mix deps.get
mix run -e "FormBuilder.App.run()" --no-halt
```

## Controls

- **Tab / Shift+Tab** - Navigate between fields and submit button
- **Up/Down** - Navigate options (radio/select/multi-select fields)
- **Space** - Toggle checkbox or select option
- **Enter** - Submit form (when on submit button)
- **Backspace** - Delete character (text/password fields)
- **Type characters** - Enter text (text/password fields)
- **Q** - Quit the application

## Field Behavior

**Text/Password Fields:**
- Type to enter text
- Backspace to delete
- Displays placeholder when empty
- Password fields show asterisks

**Checkbox:**
- Space to toggle
- Shows [x] when checked, [ ] when unchecked

**Radio Buttons:**
- Up/Down or Space to select option
- Shows (o) for selected, ( ) for unselected
- Options displayed horizontally

**Select Dropdown:**
- Shows selected value with dropdown indicator
- Expands when focused to show all options
- Up/Down to navigate, Space/Enter to select

**Multi-Select:**
- Shows all options with checkboxes
- Up/Down to navigate
- Space to toggle selection
- Multiple options can be selected

## Validation

The example demonstrates custom validators:

**Password Validator:**
```elixir
defp validate_password(value) do
  cond do
    String.length(value) < 6 ->
      {:error, "Password must be at least 6 characters"}
    not String.match?(value, ~r/[0-9]/) ->
      {:error, "Password must contain at least one number"}
    true ->
      :ok
  end
end
```

**Email Validator:**
```elixir
defp validate_email(value) do
  if value == "" or String.match?(value, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
    :ok
  else
    {:error, "Please enter a valid email address"}
  end
end
```

Errors are displayed in red below the field.

## Conditional Fields

The email frequency field demonstrates conditional visibility:

```elixir
%{
  id: :frequency,
  type: :radio,
  label: "Email frequency",
  visible_when: fn values -> values[:newsletter] end,
  options: [
    {"daily", "Daily"},
    {"weekly", "Weekly"},
    {"monthly", "Monthly"}
  ]
}
```

This field only appears when the newsletter checkbox is checked.
