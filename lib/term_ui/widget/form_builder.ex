defmodule TermUI.Widget.FormBuilder do
  @moduledoc "A pure form with text, checkbox, and select fields."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @type field :: %{
          required(:id) => term(),
          required(:label) => String.t(),
          required(:type) => :text | :checkbox | :select,
          optional(:options) => [term()],
          optional(:required) => boolean()
        }
  @type t :: %__MODULE__{
          fields: [field()],
          values: map(),
          active: non_neg_integer(),
          errors: map(),
          submit_label: String.t()
        }
  @schema Zoi.struct(__MODULE__, %{
            fields: Zoi.array() |> Zoi.default([]),
            values: Zoi.map() |> Zoi.default(%{}),
            active: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            errors: Zoi.map() |> Zoi.default(%{}),
            submit_label: Zoi.string() |> Zoi.default("Submit")
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    fields = opts |> Keyword.get(:fields, []) |> Enum.map(&normalize_field/1)

    defaults =
      Map.new(fields, fn field -> {field.id, Map.get(field, :default, default_value(field))} end)

    %__MODULE__{
      fields: fields,
      values: Map.merge(defaults, Keyword.get(opts, :values, %{})),
      submit_label: Keyword.get(opts, :submit_label, "Submit")
    }
  end

  @impl true
  def update(%Event.Key{key: :tab}, state), do: move(state, 1)
  def update(%Event.Key{key: :up}, state), do: move(state, -1)
  def update(%Event.Key{key: :down}, state), do: move(state, 1)
  def update(%Event.Key{key: :space}, state), do: toggle_or_cycle(state)
  def update(%Event.Text{text: " "}, state), do: toggle_or_insert_space(state)
  def update(%Event.Key{key: :left}, state), do: cycle(state, -1)
  def update(%Event.Key{key: :right}, state), do: cycle(state, 1)
  def update(%Event.Key{key: :backspace}, state), do: edit_text(state, &drop_last/1)
  def update(%Event.Text{text: text}, state), do: edit_text(state, &(&1 <> clean(text)))
  def update(%Event.Paste{content: text}, state), do: edit_text(state, &(&1 <> clean(text)))

  def update(%Event.Key{key: :enter}, state) do
    case validate(state) do
      %{errors: errors} = checked when map_size(errors) == 0 ->
        {checked, [{:submit, checked.values}]}

      checked ->
        {checked, [{:invalid, checked.errors}]}
    end
  end

  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: action, button: :left, y: y}, state, {_width, height})
      when action in [:press, :release] do
    case field_at(state, y, height) do
      nil ->
        {state, []}

      index ->
        state = %{state | active: index}
        if action == :release, do: activate_field(state), else: {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(state, {_width, height} = dimensions) do
    label_style = Style.new(fg: :cyan)
    active_style = Style.new(attrs: [:reverse])
    error_style = Style.new(fg: :red)

    rows =
      state.fields
      |> Enum.with_index()
      |> Enum.flat_map(fn {field, index} ->
        value = Map.get(state.values, field.id)
        value_text = render_value(field, value)
        style = if index == state.active, do: active_style, else: Style.new()
        row = [{field.label <> ": ", label_style}, {value_text, style}]

        case Map.get(state.errors, field.id) do
          nil -> [row]
          error -> [row, [{"  " <> error, error_style}]]
        end
      end)

    Helpers.frame(Enum.take(rows, height), dimensions)
  end

  @doc "Validates required fields and returns updated error data."
  @spec validate(t()) :: t()
  def validate(state) do
    errors =
      Enum.reduce(state.fields, %{}, fn field, errors ->
        value = Map.get(state.values, field.id)

        if Map.get(field, :required, false) and value in [nil, "", false],
          do: Map.put(errors, field.id, "is required"),
          else: errors
      end)

    %{state | errors: errors}
  end

  @doc "Sets one field value."
  @spec put_value(t(), term(), term()) :: t()
  def put_value(state, id, value), do: %{state | values: Map.put(state.values, id, value)}

  defp move(%{fields: []} = state, _delta), do: {state, []}

  defp move(state, delta),
    do:
      {%{state | active: rem(state.active + delta + length(state.fields), length(state.fields))},
       []}

  defp toggle_or_cycle(state) do
    case Enum.at(state.fields, state.active) do
      %{type: :checkbox, id: id} -> changed(state, id, not Map.get(state.values, id, false))
      %{type: :select} -> cycle(state, 1)
      _field -> {state, []}
    end
  end

  defp toggle_or_insert_space(state) do
    case Enum.at(state.fields, state.active) do
      %{type: type} when type in [:checkbox, :select] -> toggle_or_cycle(state)
      _field -> edit_text(state, &(&1 <> " "))
    end
  end

  defp activate_field(state) do
    case Enum.at(state.fields, state.active) do
      %{type: type} when type in [:checkbox, :select] -> toggle_or_cycle(state)
      _field -> {state, []}
    end
  end

  defp field_at(state, y, height) when y >= 0 and y < height do
    state.fields
    |> Enum.with_index()
    |> Enum.reduce_while(0, fn {field, index}, row ->
      next_row = row + if(Map.has_key?(state.errors, field.id), do: 2, else: 1)

      if y == row,
        do: {:halt, {:found, index}},
        else: {:cont, next_row}
    end)
    |> case do
      {:found, index} -> index
      _row -> nil
    end
  end

  defp field_at(_state, _y, _height), do: nil

  defp cycle(state, delta) do
    case Enum.at(state.fields, state.active) do
      %{type: :select, id: id, options: options} when options != [] ->
        current = Enum.find_index(options, &(&1 == Map.get(state.values, id))) || 0

        changed(
          state,
          id,
          Enum.at(options, rem(current + delta + length(options), length(options)))
        )

      _field ->
        {state, []}
    end
  end

  defp edit_text(state, fun) do
    case Enum.at(state.fields, state.active) do
      %{type: :text, id: id} -> changed(state, id, fun.(to_string(Map.get(state.values, id, ""))))
      _field -> {state, []}
    end
  end

  defp changed(state, id, value),
    do:
      {%{state | values: Map.put(state.values, id, value), errors: Map.delete(state.errors, id)},
       [{:changed, id, value}]}

  defp render_value(%{type: :checkbox}, true), do: "[x]"
  defp render_value(%{type: :checkbox}, _value), do: "[ ]"
  defp render_value(%{type: :select}, value), do: "‹ " <> to_string(value || "") <> " ›"
  defp render_value(_field, value), do: to_string(value || "")
  defp default_value(%{type: :checkbox}), do: false
  defp default_value(%{type: :select, options: [first | _]}), do: first
  defp default_value(_field), do: ""

  defp normalize_field(%{id: id, label: label} = field),
    do:
      field
      |> Map.put(:id, id)
      |> Map.put(:label, to_string(label))
      |> Map.put_new(:type, :text)
      |> Map.put_new(:options, [])

  defp normalize_field({id, label}),
    do: %{id: id, label: to_string(label), type: :text, options: []}

  defp clean(text), do: String.replace(text, ~r/[\x00-\x1F\x7F]/u, "")
  defp drop_last(text), do: text |> String.graphemes() |> Enum.drop(-1) |> Enum.join()
end
