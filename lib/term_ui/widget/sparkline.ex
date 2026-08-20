defmodule TermUI.Widget.Sparkline do
  @moduledoc "A pure one-row sparkline for numeric samples."

  @behaviour TermUI.Widget

  alias TermUI.Style
  alias TermUI.Widget.{ChartHelpers, Helpers}

  @levels String.graphemes("▁▂▃▄▅▆▇█")
  @type t :: %__MODULE__{
          values: [number()],
          minimum: number() | nil,
          maximum: number() | nil,
          style: Style.t(),
          label: String.t() | nil
        }
  @schema Zoi.struct(__MODULE__, %{
            values: Zoi.array(Zoi.number()) |> Zoi.default([]),
            minimum: Zoi.any() |> Zoi.default(nil),
            maximum: Zoi.any() |> Zoi.default(nil),
            style: Zoi.struct(Style) |> Zoi.default(%Style{fg: :cyan}),
            label: Zoi.any() |> Zoi.default(nil)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts),
    do: %__MODULE__{
      values: Keyword.get(opts, :values, []),
      minimum: Keyword.get(opts, :min),
      maximum: Keyword.get(opts, :max),
      style: Keyword.get(opts, :style, Style.new(fg: :cyan)),
      label: Keyword.get(opts, :label)
    }

  @impl true
  def update(_event, state), do: {state, []}

  @impl true
  def view(state, {width, _height} = dimensions) do
    prefix = if state.label, do: state.label <> " ", else: ""
    sample_width = max(width - String.length(prefix), 0)
    values = Enum.take(state.values, -sample_width)

    {minimum, maximum} =
      ChartHelpers.range(values,
        min: state.minimum || Enum.min(values, fn -> 0 end),
        max: state.maximum || Enum.max(values, fn -> 1 end)
      )

    chars =
      Enum.map_join(values, fn value ->
        Enum.at(@levels, round(ChartHelpers.normalize(value, minimum, maximum) * 7))
      end)

    Helpers.frame([[prefix, {chars, state.style}]], dimensions)
  end

  @doc "Appends one value and retains at most limit values."
  @spec push(t(), number(), pos_integer()) :: t()
  def push(state, value, limit \\ 1_000),
    do: %{state | values: Enum.take(state.values ++ [value], -max(limit, 1))}
end
