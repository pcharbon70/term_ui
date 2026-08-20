defmodule TermUI.Widget.Viewport do
  @moduledoc "A pure viewport for vertically and horizontally scrollable text rows."

  @behaviour TermUI.Widget

  alias TermUI.{DisplayWidth, Event, Frame}
  alias TermUI.Widget.Helpers

  @type t :: %__MODULE__{
          rows: [Frame.row()],
          scroll_x: non_neg_integer(),
          scroll_y: non_neg_integer(),
          page_size: pos_integer(),
          follow_end: boolean()
        }

  @schema Zoi.struct(__MODULE__, %{
            rows: Zoi.array() |> Zoi.default([]),
            scroll_x: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            scroll_y: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            page_size: Zoi.integer() |> Zoi.positive() |> Zoi.default(10),
            follow_end: Zoi.boolean() |> Zoi.default(false)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    %__MODULE__{
      rows: normalize_content(Keyword.get(opts, :content, [])),
      scroll_x: max(Keyword.get(opts, :scroll_x, 0), 0),
      scroll_y: max(Keyword.get(opts, :scroll_y, 0), 0),
      page_size: max(Keyword.get(opts, :page_size, 10), 1),
      follow_end: Keyword.get(opts, :follow_end, false)
    }
  end

  @impl true
  def update(%Event.Key{key: :up}, state), do: scroll(state, 0, -1)
  def update(%Event.Key{key: :down}, state), do: scroll(state, 0, 1)
  def update(%Event.Key{key: :left}, state), do: scroll(state, -1, 0)
  def update(%Event.Key{key: :right}, state), do: scroll(state, 1, 0)
  def update(%Event.Key{key: :page_up}, state), do: scroll(state, 0, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: scroll(state, 0, state.page_size)

  def update(%Event.Key{key: :home, modifiers: modifiers}, state) do
    if :ctrl in modifiers, do: {%{state | scroll_y: 0}, []}, else: {%{state | scroll_x: 0}, []}
  end

  def update(%Event.Key{key: :end, modifiers: modifiers}, state) do
    if :ctrl in modifiers,
      do: {%{state | scroll_y: max(length(state.rows) - state.page_size, 0)}, []},
      else: {state, []}
  end

  def update(%Event.Mouse{action: :scroll_up}, state), do: scroll(state, 0, -3)
  def update(%Event.Mouse{action: :scroll_down}, state), do: scroll(state, 0, 3)
  def update(_event, state), do: {state, []}

  @impl true
  def view(state, {width, height} = dimensions) do
    offset =
      if state.follow_end,
        do: max(length(state.rows) - height, 0),
        else: min(state.scroll_y, max(length(state.rows) - height, 0))

    rows =
      state.rows
      |> Enum.slice(offset, height)
      |> Enum.map(fn row ->
        row |> plain_text() |> drop_width(state.scroll_x) |> Frame.fit(width)
      end)

    Helpers.frame(rows, dimensions)
  end

  @doc "Replaces the content rows and keeps the scroll position valid."
  @spec set_content(t(), String.t() | [Frame.row()]) :: t()
  def set_content(state, content) do
    rows = normalize_content(content)

    scroll_y =
      if state.follow_end,
        do: max(length(rows) - state.page_size, 0),
        else: min(state.scroll_y, max(length(rows) - 1, 0))

    %{state | rows: rows, scroll_y: scroll_y}
  end

  @doc "Returns the horizontal and vertical scroll offsets."
  @spec position(t()) :: {non_neg_integer(), non_neg_integer()}
  def position(state), do: {state.scroll_x, state.scroll_y}

  defp scroll(state, dx, dy) do
    max_x =
      state.rows
      |> Enum.map(&plain_text/1)
      |> Enum.map(&DisplayWidth.width/1)
      |> Enum.max(fn -> 0 end)

    max_y = max(length(state.rows) - state.page_size, 0)

    next = %{
      state
      | scroll_x: Helpers.clamp(state.scroll_x + dx, 0, max_x),
        scroll_y: Helpers.clamp(state.scroll_y + dy, 0, max_y),
        follow_end: false
    }

    {next, [{:scrolled, {next.scroll_x, next.scroll_y}}]}
  end

  defp normalize_content(content) when is_binary(content),
    do: String.split(content, "\n", trim: false)

  defp normalize_content(content) when is_list(content), do: content
  defp normalize_content(content), do: [to_string(content)]
  defp plain_text(row) when is_binary(row), do: row

  defp plain_text(row),
    do:
      Enum.map_join(row, fn
        {text, _style} -> IO.iodata_to_binary(text)
        text -> IO.iodata_to_binary(text)
      end)

  defp drop_width(text, 0), do: text
  defp drop_width(text, width), do: text |> String.graphemes() |> do_drop_width(width)

  defp do_drop_width(graphemes, width) when width <= 0, do: Enum.join(graphemes)
  defp do_drop_width([], _width), do: ""

  defp do_drop_width([grapheme | rest], width) do
    grapheme_width = max(DisplayWidth.width(grapheme), 0)

    if grapheme_width <= width,
      do: do_drop_width(rest, width - grapheme_width),
      else: " " <> Enum.join(rest)
  end
end
