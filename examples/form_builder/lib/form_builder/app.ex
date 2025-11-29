defmodule FormBuilder.App do
  @moduledoc """
  FormBuilder Widget Example

  This example demonstrates how to use the TermUI.Widgets.FormBuilder widget
  for creating structured forms with multiple field types.

  Features demonstrated:
  - Text and password fields
  - Checkbox fields
  - Radio button groups
  - Select dropdowns
  - Multi-select fields
  - Field validation
  - Conditional fields
  - Form submission

  Controls:
  - Tab/Shift+Tab: Navigate between fields
  - Up/Down: Navigate options (radio/select)
  - Space: Toggle checkbox, select option
  - Enter: Submit form (on submit button)
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.FormBuilder

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    props =
      FormBuilder.new(
        fields: [
          # Basic text fields
          %{id: :username, type: :text, label: "Username", required: true,
            placeholder: "Enter username"},
          %{id: :password, type: :password, label: "Password", required: true,
            validators: [&validate_password/1]},
          %{id: :email, type: :text, label: "Email",
            validators: [&validate_email/1]},

          # Checkbox
          %{id: :newsletter, type: :checkbox, label: "Subscribe to newsletter"},

          # Conditional field - only shown when newsletter is checked
          %{id: :frequency, type: :radio, label: "Email frequency",
            visible_when: fn values -> values[:newsletter] end,
            options: [
              {"daily", "Daily"},
              {"weekly", "Weekly"},
              {"monthly", "Monthly"}
            ]},

          # Select dropdown
          %{id: :country, type: :select, label: "Country",
            options: [
              {"us", "United States"},
              {"uk", "United Kingdom"},
              {"ca", "Canada"},
              {"au", "Australia"},
              {"de", "Germany"}
            ]},

          # Multi-select
          %{id: :interests, type: :multi_select, label: "Interests",
            options: [
              {"tech", "Technology"},
              {"sports", "Sports"},
              {"music", "Music"},
              {"art", "Art"},
              {"travel", "Travel"}
            ]}
        ],
        on_submit: fn values -> send(self(), {:form_submitted, values}) end,
        on_change: fn _field_id, _value -> :ok end,
        submit_label: "Register",
        label_width: 18,
        field_width: 25
      )

    {:ok, form_state} = FormBuilder.init(props)

    %{
      form: form_state,
      submitted_data: nil,
      message: nil
    }
  end

  # Custom validators
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

  defp validate_email(value) do
    if value == "" or String.match?(value, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      :ok
    else
      {:error, "Please enter a valid email address"}
    end
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"] do
    {:msg, :quit}
  end

  def event_to_msg(event, _state) do
    # Pass all other events to the form
    {:msg, {:form_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update({:form_event, event}, state) do
    {:ok, new_form} = FormBuilder.handle_event(event, state.form)
    {%{state | form: new_form}, []}
  end

  def update({:form_submitted, values}, state) do
    {%{state | submitted_data: values, message: "Form submitted successfully!"}, []}
  end

  def update(_msg, state) do
    {state, []}
  end

  @doc """
  Handle info messages (for form submission callback).
  """
  def handle_info({:form_submitted, values}, state) do
    {%{state | submitted_data: values, message: "Form submitted successfully!"}, []}
  end

  def handle_info(_msg, state) do
    {state, []}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("FormBuilder Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(""),

      # Instructions
      render_instructions(),
      text(""),

      # Form
      render_form_section(state),
      text(""),

      # Submitted data (if any)
      render_submitted_data(state),

      # Status message
      render_message(state)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_instructions do
    stack(:vertical, [
      text("Controls:", Style.new(fg: :yellow)),
      text("  Tab/Shift+Tab  Navigate between fields"),
      text("  Up/Down        Navigate options (radio/select)"),
      text("  Space          Toggle checkbox, select option"),
      text("  Enter          Submit form (on submit button)"),
      text("  Q              Quit")
    ])
  end

  defp render_form_section(state) do
    box_style = Style.new(fg: :white)

    stack(:vertical, [
      text("--- Registration Form ---", box_style),
      text(""),
      FormBuilder.render(state.form, %{width: 70, height: 20})
    ])
  end

  defp render_submitted_data(state) do
    case state.submitted_data do
      nil ->
        empty()

      data ->
        stack(:vertical, [
          text("--- Submitted Data ---", Style.new(fg: :green, attrs: [:bold])),
          text(""),
          render_data_row("Username", data[:username]),
          render_data_row("Password", String.duplicate("*", String.length(data[:password] || ""))),
          render_data_row("Email", data[:email]),
          render_data_row("Newsletter", if(data[:newsletter], do: "Yes", else: "No")),
          if data[:newsletter] do
            render_data_row("Frequency", data[:frequency] || "(not set)")
          else
            empty()
          end,
          render_data_row("Country", data[:country]),
          render_data_row("Interests", Enum.join(data[:interests] || [], ", "))
        ])
    end
  end

  defp render_data_row(label, value) do
    text("  #{String.pad_trailing(label <> ":", 15)} #{value}")
  end

  defp render_message(state) do
    case state.message do
      nil -> empty()
      msg -> text(msg, Style.new(fg: :green, attrs: [:bold]))
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the form builder example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
