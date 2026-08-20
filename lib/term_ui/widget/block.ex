defmodule TermUI.Widget.Block do
  @moduledoc "A bordered content block that produces a frame."

  @behaviour TermUI.Widget

  alias TermUI.{Frame, Style}
  alias TermUI.Widget.Helpers

  @type t :: %__MODULE__{
          rows: [Frame.row()],
          title: String.t() | nil,
          padding: non_neg_integer(),
          style: Style.t(),
          border_style: Style.t()
        }

  @schema Zoi.struct(__MODULE__, %{
            rows: Zoi.array() |> Zoi.default([]),
            title: Zoi.any() |> Zoi.default(nil),
            padding: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            style: Zoi.struct(Style) |> Zoi.default(%Style{}),
            border_style: Zoi.struct(Style) |> Zoi.default(%Style{fg: :bright_black})
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    %__MODULE__{
      rows: normalize_content(Keyword.get(opts, :content, Keyword.get(opts, :rows, []))),
      title: Keyword.get(opts, :title),
      padding: max(Keyword.get(opts, :padding, 0), 0),
      style: Keyword.get(opts, :style, Style.new()),
      border_style: Keyword.get(opts, :border_style, Style.new(fg: :bright_black))
    }
  end

  @impl true
  def update(_event, state), do: {state, []}

  @impl true
  def view(state, {width, _height} = dimensions) do
    inner_width = max(width - 2 - state.padding * 2, 0)
    padding = String.duplicate(" ", state.padding)

    rows =
      List.duplicate("", state.padding) ++
        Enum.flat_map(state.rows, fn row ->
          row
          |> plain_text()
          |> Frame.wrap(max(inner_width, 1))
          |> Enum.map(fn line -> [{padding, state.style}, {line, state.style}, padding] end)
        end) ++ List.duplicate("", state.padding)

    rows = Helpers.border(rows, dimensions, title: state.title, border_style: state.border_style)
    Helpers.frame(rows, dimensions)
  end

  @doc "Replaces the block content."
  @spec set_content(t(), String.t() | [Frame.row()]) :: t()
  def set_content(state, content), do: %{state | rows: normalize_content(content)}

  defp normalize_content(content) when is_binary(content),
    do: String.split(content, "\n", trim: false)

  defp normalize_content(content) when is_list(content), do: content
  defp normalize_content(content), do: [to_string(content)]

  defp plain_text(row) when is_binary(row), do: row

  defp plain_text(row) when is_list(row) do
    Enum.map_join(row, fn
      {text, %Style{}} -> IO.iodata_to_binary(text)
      text -> IO.iodata_to_binary(text)
    end)
  end
end
