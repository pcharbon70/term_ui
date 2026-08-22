defmodule TermUI.Widget.Toast do
  @moduledoc "A pure dismissible notification and bounded toast collection."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @type toast_type :: :info | :success | :warning | :error
  @type t :: %__MODULE__{
          id: term(),
          message: String.t(),
          type: toast_type(),
          visible: boolean(),
          duration: pos_integer() | :infinity,
          elapsed: non_neg_integer()
        }
  @schema Zoi.struct(__MODULE__, %{
            id: Zoi.any() |> Zoi.default(nil),
            message: Zoi.string() |> Zoi.default(""),
            type: Zoi.enum([:info, :success, :warning, :error]) |> Zoi.default(:info),
            visible: Zoi.boolean() |> Zoi.default(true),
            duration:
              Zoi.union([Zoi.integer() |> Zoi.positive(), Zoi.literal(:infinity)])
              |> Zoi.default(5_000),
            elapsed: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts),
    do: %__MODULE__{
      id: Keyword.get(opts, :id, make_ref()),
      message: opts |> Keyword.get(:message, "") |> to_string(),
      type: Keyword.get(opts, :type, :info),
      duration: Keyword.get(opts, :duration, 5_000)
    }

  @impl true
  def update(%Event.Key{key: :escape}, state),
    do: {%{state | visible: false}, [{:dismissed, state.id}]}

  def update(%Event.Mouse{action: :release, button: :left}, state),
    do: {%{state | visible: false}, [{:dismissed, state.id}]}

  def update(_event, state), do: {state, []}

  @impl true
  def view(%{visible: false}, dimensions), do: Helpers.frame([], dimensions)

  def view(state, dimensions) do
    {icon, color} =
      case state.type do
        :success -> {"✓", :green}
        :warning -> {"!", :yellow}
        :error -> {"×", :red}
        :info -> {"i", :cyan}
      end

    rows =
      Helpers.border(
        [[{icon <> " ", Style.new(fg: color, attrs: [:bold])}, state.message]],
        dimensions
      )

    Helpers.frame(rows, dimensions)
  end

  @doc "Advances the toast clock and hides an expired toast."
  @spec tick(t(), non_neg_integer()) :: t()
  def tick(%{duration: :infinity} = state, _elapsed), do: state

  def tick(state, elapsed) do
    elapsed = state.elapsed + max(elapsed, 0)
    %{state | elapsed: elapsed, visible: elapsed < state.duration}
  end

  defmodule Manager do
    @moduledoc "A pure bounded toast collection."
    alias TermUI.Widget.Toast

    @type t :: %__MODULE__{toasts: [Toast.t()], limit: pos_integer()}
    @schema Zoi.struct(__MODULE__, %{
              toasts: Zoi.array(Zoi.struct(Toast)) |> Zoi.default([]),
              limit: Zoi.integer() |> Zoi.positive() |> Zoi.default(5)
            })
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    @doc "Creates an empty bounded toast manager."
    @spec new(keyword()) :: t()
    def new(opts \\ []), do: %__MODULE__{limit: max(Keyword.get(opts, :limit, 5), 1)}

    @doc "Adds one toast and removes entries beyond the manager limit."
    @spec add(t(), iodata(), Toast.toast_type(), keyword()) :: t()
    def add(manager, message, type \\ :info, opts \\ []) do
      toast = Toast.init(Keyword.merge(opts, message: message, type: type))
      %{manager | toasts: Enum.take([toast | manager.toasts], manager.limit)}
    end

    @doc "Advances all toast clocks and removes expired entries."
    @spec tick(t(), non_neg_integer()) :: t()
    def tick(manager, elapsed),
      do: %{
        manager
        | toasts:
            manager.toasts
            |> Enum.map(&Toast.tick(&1, elapsed))
            |> Enum.filter(& &1.visible)
      }
  end
end
