defmodule TermUI.Widget.Table do
  @moduledoc "A pure scrollable table with column definitions and row selection."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers
  alias TermUI.Widget.Table.Column

  # Styled table spans contain MapSet's opaque representation through Style.t().
  @dialyzer {:nowarn_function, view: 2, render_cells: 4}

  @type t :: %__MODULE__{
          columns: [Column.t()],
          rows: [term()],
          cursor: non_neg_integer(),
          offset: non_neg_integer(),
          page_size: pos_integer(),
          show_header: boolean()
        }

  defstruct columns: [],
            rows: [],
            cursor: 0,
            offset: 0,
            page_size: 10,
            show_header: true

  @impl true
  def init(opts) do
    %__MODULE__{
      columns: opts |> Keyword.get(:columns, []) |> Enum.map(&normalize_column/1),
      rows: Keyword.get(opts, :rows, []),
      page_size: max(Keyword.get(opts, :page_size, 10), 1),
      show_header: Keyword.get(opts, :show_header, true)
    }
  end

  @impl true
  def update(%Event.Key{key: :up}, state), do: move(state, -1)
  def update(%Event.Key{key: :down}, state), do: move(state, 1)
  def update(%Event.Key{key: :home}, state), do: move_to(state, 0)
  def update(%Event.Key{key: :end}, state), do: move_to(state, length(state.rows) - 1)
  def update(%Event.Key{key: :page_up}, state), do: move(state, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: move(state, state.page_size)

  def update(%Event.Key{key: :enter}, state) do
    case Enum.at(state.rows, state.cursor) do
      nil -> {state, []}
      row -> {state, [{:selected, row}]}
    end
  end

  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: action, button: :left, y: y}, state, {_width, height})
      when action in [:press, :release] do
    header_height = if state.show_header, do: 1, else: 0
    body_height = max(height - header_height, 0)
    offset = visible_offset(state.cursor, state.offset, body_height)
    index = offset + y - header_height

    if y >= header_height and y < height and index < length(state.rows) do
      state = %{state | cursor: index, offset: offset}

      if action == :release,
        do: update(Event.key(:enter), state),
        else: {state, []}
    else
      {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(state, {width, height} = dimensions) do
    widths = column_widths(state.columns, width)
    header_height = if state.show_header, do: 1, else: 0
    body_height = max(height - header_height, 0)
    offset = visible_offset(state.cursor, state.offset, body_height)
    header_style = Style.new(fg: :cyan, attrs: [:bold, :underline])
    cursor_style = Style.new(attrs: [:reverse])

    header =
      if state.show_header,
        do: [
          render_cells(Enum.map(state.columns, & &1.label), state.columns, widths, header_style)
        ],
        else: []

    body =
      state.rows
      |> Enum.slice(offset, body_height)
      |> Enum.with_index(offset)
      |> Enum.map(fn {row, index} ->
        values = Enum.map(state.columns, &cell_value(row, &1.key))

        render_cells(
          values,
          state.columns,
          widths,
          if(index == state.cursor, do: cursor_style, else: Style.new())
        )
      end)

    Helpers.frame(header ++ body, dimensions)
  end

  @doc "Replaces all table rows."
  @spec set_rows(t(), [term()]) :: t()
  def set_rows(state, rows),
    do: %{state | rows: rows, cursor: min(state.cursor, max(length(rows) - 1, 0))}

  defp move(state, delta), do: move_to(state, state.cursor + delta)

  defp move_to(state, cursor) do
    cursor = Helpers.clamp(cursor, 0, max(length(state.rows) - 1, 0))
    offset = visible_offset(cursor, state.offset, state.page_size)
    {%{state | cursor: cursor, offset: offset}, []}
  end

  defp visible_offset(_cursor, offset, 0), do: offset
  defp visible_offset(cursor, offset, _height) when cursor < offset, do: cursor

  defp visible_offset(cursor, offset, height) when cursor >= offset + height,
    do: cursor - height + 1

  defp visible_offset(_cursor, offset, _height), do: offset

  defp render_cells(values, columns, widths, style) do
    values
    |> Enum.zip(columns)
    |> Enum.zip(widths)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{{value, column}, cell_width}, index} ->
      separator = if index == length(widths) - 1, do: "", else: " │ "

      [
        {Helpers.align(display_value(value), cell_width, column.align), style},
        {separator, Style.new(fg: :bright_black)}
      ]
    end)
  end

  defp column_widths(columns, width) do
    separators = max(length(columns) - 1, 0) * 3
    available = max(width - separators, length(columns))

    fixed =
      Enum.reduce(columns, 0, fn
        %{width: column_width}, sum when is_integer(column_width) -> sum + column_width
        _, sum -> sum
      end)

    automatic = Enum.count(columns, &(&1.width == :auto))

    auto_width =
      if automatic > 0, do: max(div(max(available - fixed, automatic), automatic), 1), else: 1

    Enum.map(columns, fn %{width: column_width} ->
      if is_integer(column_width), do: column_width, else: auto_width
    end)
  end

  defp cell_value(row, key) when is_map(row) do
    case Map.fetch(row, key) do
      {:ok, value} -> value
      :error -> string_key_value(row, key)
    end
  end

  defp cell_value(row, key) when is_list(row) and is_integer(key), do: Enum.at(row, key)

  defp cell_value(row, key)
       when is_tuple(row) and is_integer(key) and key >= 0 and key < tuple_size(row),
       do: elem(row, key)

  defp cell_value(_row, _key), do: nil

  defp string_key_value(row, key) when is_atom(key) or is_integer(key) or is_binary(key),
    do: Map.get(row, to_string(key))

  defp string_key_value(_row, _key), do: nil

  defp display_value(nil), do: ""

  defp display_value(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: inspect(value)
  end

  defp normalize_column(%Column{} = column), do: column
  defp normalize_column({key, label}), do: Column.new(key, label)
  defp normalize_column(key), do: Column.new(key, to_string(key))
end
