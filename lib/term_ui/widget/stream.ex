defmodule TermUI.Widget.Stream do
  @moduledoc "A pure bounded stream view. The parent supplies new items."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Frame, Style}
  alias TermUI.Widget.Helpers

  @type t :: %__MODULE__{
          items: [term()],
          limit: pos_integer(),
          paused: boolean(),
          offset: non_neg_integer(),
          page_size: pos_integer(),
          formatter: (term() -> iodata())
        }
  @schema Zoi.struct(__MODULE__, %{
            items: Zoi.array() |> Zoi.default([]),
            limit: Zoi.integer() |> Zoi.positive() |> Zoi.default(1_000),
            paused: Zoi.boolean() |> Zoi.default(false),
            offset: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            page_size: Zoi.integer() |> Zoi.positive() |> Zoi.default(20),
            formatter: Zoi.function() |> Zoi.default(&__MODULE__.default_format/1)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts),
    do: %__MODULE__{
      items: Enum.take(Keyword.get(opts, :items, []), -max(Keyword.get(opts, :limit, 1_000), 1)),
      limit: max(Keyword.get(opts, :limit, 1_000), 1),
      page_size: max(Keyword.get(opts, :page_size, 20), 1),
      formatter: Keyword.get(opts, :formatter, &__MODULE__.default_format/1)
    }

  @impl true
  def update(%Event.Key{key: :space}, state),
    do: {%{state | paused: not state.paused}, [{:paused, not state.paused}]}

  def update(%Event.Text{text: " "}, state),
    do: {%{state | paused: not state.paused}, [{:paused, not state.paused}]}

  def update(%Event.Key{key: :up}, state), do: scroll(state, -1)
  def update(%Event.Key{key: :down}, state), do: scroll(state, 1)
  def update(%Event.Key{key: :page_up}, state), do: scroll(state, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: scroll(state, state.page_size)

  def update(%Event.Key{key: :end}, state),
    do: {%{state | offset: max(length(state.items) - state.page_size, 0)}, []}

  def update(_event, state), do: {state, []}

  @impl true
  def view(state, {width, height} = dimensions) do
    status =
      if state.paused,
        do: [{" PAUSED ", Style.new(fg: :black, bg: :yellow, attrs: [:bold])}],
        else: [{" LIVE ", Style.new(fg: :black, bg: :green, attrs: [:bold])}]

    body_height = max(height - 1, 0)

    offset =
      if state.paused,
        do: min(state.offset, max(length(state.items) - body_height, 0)),
        else: max(length(state.items) - body_height, 0)

    rows =
      state.items
      |> Enum.slice(offset, body_height)
      |> Enum.flat_map(fn item ->
        item |> state.formatter.() |> IO.iodata_to_binary() |> Frame.wrap(width)
      end)
      |> Enum.take(body_height)

    Helpers.frame([status | rows], dimensions)
  end

  @doc "Appends one stream item unless the view is paused."
  @spec push(t(), term()) :: t()
  def push(%{paused: true} = state, _item), do: state
  def push(state, item), do: %{state | items: Enum.take(state.items ++ [item], -state.limit)}

  @doc false
  def default_format(item), do: to_string(item)

  defp scroll(state, delta) do
    offset = Helpers.scroll(state.offset, delta, length(state.items), state.page_size)
    {%{state | offset: offset, paused: true}, [{:scrolled, offset}]}
  end
end
