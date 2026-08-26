defmodule TermUI.Widget.ContextMenu do
  @moduledoc "A pure positioned context menu built on `TermUI.Widget.Menu`."

  @behaviour TermUI.Widget

  alias TermUI.Widget.Menu

  @type t :: %__MODULE__{menu: Menu.t(), position: {non_neg_integer(), non_neg_integer()}}
  defstruct menu: %Menu{},
            position: {0, 0}

  defdelegate action(id, label, opts \\ []), to: Menu
  defdelegate separator(), to: Menu

  @impl true
  def init(opts) do
    %__MODULE__{menu: Menu.init(opts), position: Keyword.get(opts, :position, {0, 0})}
  end

  @impl true
  def update(event, state) do
    {menu, messages} = Menu.update(event, state.menu)
    {%{state | menu: menu}, messages}
  end

  @impl true
  def mouse(event, state, dimensions) do
    {menu, messages} = Menu.mouse(event, state.menu, dimensions)
    {%{state | menu: menu}, messages}
  end

  @impl true
  def view(state, dimensions), do: Menu.view(state.menu, dimensions)

  @doc "Returns the requested zero-based overlay position."
  @spec position(t()) :: {non_neg_integer(), non_neg_integer()}
  def position(state), do: state.position

  @doc "Moves the context menu."
  @spec move_to(t(), {non_neg_integer(), non_neg_integer()}) :: t()
  def move_to(state, position), do: %{state | position: position}
end
