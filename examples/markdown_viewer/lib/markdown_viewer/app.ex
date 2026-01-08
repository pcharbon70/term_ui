defmodule MarkdownViewer.App do
  @moduledoc """
  Markdown Viewer Widget Example

  Demonstrates the TermUI.Widgets.MarkdownViewer widget.
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.MarkdownViewer

  @sample_markdown """
  # Markdown Viewer Demo

  Welcome to the **Markdown Viewer** widget demonstration. This component
  renders *markdown* content with `syntax highlighting` for code blocks.

  ## Features

  - Full CommonMark support via MDEx
  - Syntax highlighting for Elixir and Erlang
  - Keyboard navigation and scrolling
  - Focusable code blocks with copy support

  ## Code Examples

  ### Pattern Matching

  ```elixir
  defmodule Calculator do
    def compute({:add, a, b}), do: a + b
    def compute({:subtract, a, b}), do: a - b
    def compute({:multiply, a, b}), do: a * b
    def compute({:divide, _a, 0}), do: {:error, :division_by_zero}
    def compute({:divide, a, b}), do: a / b
  end

  # Usage
  Calculator.compute({:add, 10, 5})
  Calculator.compute({:multiply, 3, 7})
  ```

  ### Working with GenServer

  ```elixir
  defmodule KeyValueStore do
    use GenServer

    # Client API
    def start_link(opts \\\\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def get(key) do
      GenServer.call(__MODULE__, {:get, key})
    end

    def put(key, value) do
      GenServer.cast(__MODULE__, {:put, key, value})
    end

    # Server Callbacks
    @impl true
    def init(_opts) do
      {:ok, %{}}
    end

    @impl true
    def handle_call({:get, key}, _from, state) do
      {:reply, Map.get(state, key), state}
    end

    @impl true
    def handle_cast({:put, key, value}, state) do
      {:noreply, Map.put(state, key, value)}
    end
  end
  ```

  ### Enum and List Comprehensions

  ```elixir
  # Get all even numbers from 1 to 100
  evens = for n <- 1..100, rem(n, 2) == 0, do: n

  # Parse a list of strings into integers
  numbers = ["1", "42", "7", "100"]
  parsed = for str <- numbers, into: [] do
    String.to_integer(str)
  end

  # Filter and map in one pass
  squared_evens =
    1..20
    |> Enum.filter(&(rem(&1, 2) == 0))
    |> Enum.map(&(&1 * &1))

  # Using Enum.reduce
  sum = Enum.reduce(1..10, 0, fn i, acc -> acc + i end)
  ```

  ### Structs and Protocols

  ```elixir
  defmodule User do
    @type t :: %__MODULE__{
      name: String.t(),
      age: pos_integer(),
      email: String.t()
    }

    defstruct [:name, :age, :email]

    def new(name, age, email) do
      %__MODULE__{
        name: name,
        age: age,
        email: email
      }
    end
  end

  # Pattern matching on structs
  def is_adult?(%User{age: age}) when age >= 18, do: true
  def is_adult?(%User{}), do: false
  ```

  ### Erlang Example

  ```erlang
  -module(sorter).
  -export([quicksort/1]).

  %% QuickSort implementation in Erlang
  quicksort([]) -> [];
  quicksort([Pivot | Rest]) ->
      {Smaller, Larger} = partition(Pivot, Rest, [], []),
      quicksort(Smaller) ++ [Pivot] ++ quicksort(Larger).

  partition(_Pivot, [], Smaller, Larger) ->
      {Smaller, Larger};
  partition(Pivot, [H | T], Smaller, Larger) when H =< Pivot ->
      partition(Pivot, T, [H | Smaller], Larger);
  partition(Pivot, [H | T], Smaller, Larger) ->
      partition(Pivot, T, Smaller, [H | Larger]).
  ```

  ## Text Styling

  You can use **bold text**, *italic text*, or `inline code`.
  Links are also supported: [TermUI](https://github.com/pcharbon70/term_ui)

  ## Lists

  ### Unordered List

  - First item
  - Second item with **bold**
  - Third item with `code`

  ### Ordered List

  1. First step
  2. Second step
  3. Third step

  ## Blockquotes

  > The best way to predict the future is to invent it.
  > — Alan Kay

  ---

  Enjoy using the Markdown Viewer!
  """

  def init(_opts) do
    props = MarkdownViewer.new(
      content: @sample_markdown,
      width: 76,
      height: 20
    )

    {:ok, viewer_state} = MarkdownViewer.init(props)

    %{
      viewer_state: viewer_state,
      scroll_pos: 0,
      content_height: viewer_state.content_height
    }
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :scroll_up}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :scroll_down}
  def event_to_msg(%Event.Key{key: :page_up}, _state), do: {:msg, :page_up}
  def event_to_msg(%Event.Key{key: :page_down}, _state), do: {:msg, :page_down}
  def event_to_msg(%Event.Key{key: :home}, _state), do: {:msg, :scroll_top}
  def event_to_msg(%Event.Key{key: :end}, _state), do: {:msg, :scroll_bottom}
  def event_to_msg(%Event.Key{key: :tab, modifiers: []}, _state), do: {:msg, :next_code_block}
  def event_to_msg(%Event.Key{key: :tab, modifiers: [:shift]}, _state), do: {:msg, :prev_code_block}
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :copy_code}
  def event_to_msg(%Event.Key{char: ?c}, _state), do: {:msg, :copy_code}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  def update(:scroll_up, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :up}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:scroll_down, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :down}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:page_up, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :page_up}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:page_down, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :page_down}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:scroll_top, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :home}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:scroll_bottom, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :end}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:next_code_block, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :tab}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:prev_code_block, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :tab, modifiers: [:shift]}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:copy_code, state) do
    {:ok, new_viewer} = MarkdownViewer.handle_event(%Event.Key{key: :enter}, state.viewer_state)
    {update_scroll_info(%{state | viewer_state: new_viewer}), []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  defp update_scroll_info(state) do
    scroll_y = state.viewer_state.scroll_y
    content_height = state.viewer_state.content_height
    %{state | scroll_pos: scroll_y, content_height: content_height}
  end

  def view(state) do
    stack(:vertical, [
      render_title_bar(),
      MarkdownViewer.render(state.viewer_state, %{width: 76, height: 20}),
      render_status_bar(state)
    ])
  end

  defp render_title_bar do
    title = " Markdown Viewer Demo "
    padding = String.duplicate("─", div(76 - String.length(title), 2))
    text(padding <> title <> padding, Style.new(fg: :cyan, attrs: [:bold]))
  end

  defp render_status_bar(state) do
    scroll_text =
      if state.content_height > 20 do
        pct = min(100, round(state.scroll_pos / max(1, state.content_height - 20) * 100))
        "Line: #{state.scroll_pos + 1}/#{state.content_height} (#{pct}%)"
      else
        "Line: #{state.scroll_pos + 1}/#{state.content_height}"
      end

    help = "↑↓:Scroll | PgUp/Dn:Page | Home/End:Top/Bot | Tab:Code | Enter/c:Copy | Q:Quit"
    left_pad = String.pad_trailing(" " <> scroll_text, 54)
    right = " " <> help
    text(left_pad <> right, Style.new(fg: :bright_black))
  end

  def run do
    TermUI.Runtime.run(
      root: __MODULE__,
      fps: 60,
      mouse: true,
      title: "Markdown Viewer Demo"
    )
  end
end
