defmodule TermUI.Widget.SplitPane do
  @moduledoc "A pure horizontal or vertical frame composition widget."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Frame, Style}

  @type content ::
          Frame.t()
          | [Frame.row()]
          | String.t()
          | {module(), term()}
          | (TermUI.Widget.dimensions() -> Frame.t())
  @type t :: %__MODULE__{
          first: content(),
          second: content(),
          direction: :horizontal | :vertical,
          ratio: float(),
          dragging: boolean()
        }
  @schema Zoi.struct(__MODULE__, %{
            first: Zoi.any() |> Zoi.default([]),
            second: Zoi.any() |> Zoi.default([]),
            direction: Zoi.enum([:horizontal, :vertical]) |> Zoi.default(:horizontal),
            ratio: Zoi.number() |> Zoi.gte(0.1) |> Zoi.lte(0.9) |> Zoi.default(0.5),
            dragging: Zoi.boolean() |> Zoi.default(false)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    %__MODULE__{
      first: Keyword.get(opts, :first, []),
      second: Keyword.get(opts, :second, []),
      direction: Keyword.get(opts, :direction, :horizontal),
      ratio: opts |> Keyword.get(:ratio, 0.5) |> max(0.1) |> min(0.9),
      dragging: false
    }
  end

  @impl true
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: :press, button: :left} = event, state, dimensions) do
    if separator?(state, event, dimensions),
      do: {%{state | dragging: true}, []},
      else: {state, []}
  end

  def mouse(
        %Event.Mouse{action: :drag, button: :left} = event,
        %{dragging: true} = state,
        dimensions
      ) do
    ratio = pointer_ratio(state.direction, event, dimensions)
    state = %{state | ratio: ratio}
    {state, [{:resized, ratio}]}
  end

  def mouse(%Event.Mouse{action: :release, button: :left}, state, _dimensions),
    do: {%{state | dragging: false}, []}

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(%{direction: :vertical} = state, {width, height}) do
    first_height = max(round((height - 1) * state.ratio), 1)
    second_height = max(height - first_height - 1, 1)

    base =
      Frame.new(width, height)
      |> Frame.put_row(first_height + 1, [
        {String.duplicate("─", width), Style.new(fg: :bright_black)}
      ])

    base
    |> Frame.overlay(resolve(state.first, {width, first_height}), 1, 1)
    |> Frame.overlay(resolve(state.second, {width, second_height}), 1, first_height + 2)
  end

  def view(state, {width, height}) do
    first_width = max(round((width - 1) * state.ratio), 1)
    second_width = max(width - first_width - 1, 1)
    separator = Style.to_cell(Style.new(fg: :bright_black), "│")

    base =
      Enum.reduce(1..height, Frame.new(width, height), fn row, frame ->
        Frame.put_cell(frame, row, first_width + 1, separator)
      end)

    base
    |> Frame.overlay(resolve(state.first, {first_width, height}), 1, 1)
    |> Frame.overlay(resolve(state.second, {second_width, height}), first_width + 2, 1)
  end

  defp resolve(%Frame{} = frame, _dimensions), do: frame

  defp resolve({module, widget_state}, dimensions),
    do: TermUI.Widget.view(module, widget_state, dimensions)

  defp resolve(fun, dimensions) when is_function(fun, 1), do: fun.(dimensions)

  defp resolve(content, {width, height}) when is_binary(content),
    do: Frame.from_rows(String.split(content, "\n", trim: false), width, height)

  defp resolve(rows, {width, height}) when is_list(rows), do: Frame.from_rows(rows, width, height)

  defp separator?(%{direction: :horizontal, ratio: ratio}, event, {width, _height}),
    do: event.x == max(round((width - 1) * ratio), 1)

  defp separator?(%{direction: :vertical, ratio: ratio}, event, {_width, height}),
    do: event.y == max(round((height - 1) * ratio), 1)

  defp pointer_ratio(:horizontal, event, {width, _height}),
    do: (event.x / max(width - 1, 1)) |> max(0.1) |> min(0.9)

  defp pointer_ratio(:vertical, event, {_width, height}),
    do: (event.y / max(height - 1, 1)) |> max(0.1) |> min(0.9)
end
