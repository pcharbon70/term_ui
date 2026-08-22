defmodule TermUI.Widget.MarkdownViewer do
  @moduledoc "A pure, scrollable MDEx Markdown viewer with selectable code blocks."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Frame, Markdown}
  alias TermUI.Markdown.Document

  @type t :: %__MODULE__{
          content: String.t(),
          scroll: non_neg_integer() | :end,
          page_size: pos_integer(),
          elements: [Markdown.element()],
          focused: non_neg_integer(),
          content_limit: pos_integer(),
          document: Document.t()
        }

  @schema Zoi.struct(__MODULE__, %{
            content: Zoi.string() |> Zoi.default(""),
            scroll:
              Zoi.union([Zoi.integer() |> Zoi.non_negative(), Zoi.literal(:end)])
              |> Zoi.default(0),
            page_size: Zoi.integer() |> Zoi.positive() |> Zoi.default(20),
            elements: Zoi.array() |> Zoi.default([]),
            focused: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            content_limit: Zoi.integer() |> Zoi.positive() |> Zoi.default(2_000_000),
            document: Zoi.struct(Document) |> Zoi.default(%Document{})
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    content_limit = max(Keyword.get(opts, :content_limit, 2_000_000), 1)

    document =
      Document.new(Keyword.get(opts, :content, "") |> to_string(), content_limit: content_limit)

    %__MODULE__{
      content: document.content,
      page_size: max(Keyword.get(opts, :page_size, 20), 1),
      elements: Markdown.code_blocks(document),
      content_limit: content_limit,
      document: document
    }
  end

  @impl true
  def update(%Event.Key{key: :up}, state), do: scroll(state, -1)
  def update(%Event.Key{key: :down}, state), do: scroll(state, 1)
  def update(%Event.Key{key: :page_up}, state), do: scroll(state, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: scroll(state, state.page_size)
  def update(%Event.Key{key: :home}, state), do: {%{state | scroll: 0}, []}
  def update(%Event.Key{key: :end}, state), do: {%{state | scroll: :end}, []}

  def update(%Event.Key{key: :tab, modifiers: modifiers}, state),
    do: focus(state, if(:shift in modifiers, do: -1, else: 1))

  def update(%Event.Key{key: :enter}, state), do: copy_focused(state)
  def update(%Event.Text{text: "c"}, state), do: copy_focused(state)
  def update(%Event.Mouse{action: :scroll_up}, state), do: scroll(state, -3)
  def update(%Event.Mouse{action: :scroll_down}, state), do: scroll(state, 3)
  def update(_event, state), do: {state, []}

  @impl true
  def view(state, {width, height} = dimensions) do
    focused_id = state.elements |> Enum.at(state.focused) |> then(&if(&1, do: &1.id))
    result = Markdown.render_with_elements(state.document, width, focused_element_id: focused_id)

    offset =
      if state.scroll == :end,
        do: max(result.content_height - height, 0),
        else: min(state.scroll, max(result.content_height - height, 0))

    rows = Enum.slice(result.lines, offset, height)
    Frame.from_rows(rows, elem(dimensions, 0), elem(dimensions, 1))
  end

  @doc "Replaces Markdown content and resets navigation."
  @spec set_content(t(), String.t()) :: t()
  def set_content(state, content) do
    document = Document.replace(state.document, content)

    %{
      state
      | content: document.content,
        document: document,
        scroll: 0,
        focused: 0,
        elements: Markdown.code_blocks(document)
    }
  end

  @doc "Appends a Markdown fragment within the configured content bound."
  @spec append(t(), String.t()) :: t()
  def append(state, fragment) do
    document = Document.append(state.document, fragment)

    %{
      state
      | content: document.content,
        document: document,
        elements: Markdown.code_blocks(document),
        scroll: :end
    }
  end

  defp scroll(state, delta) do
    scroll = if state.scroll == :end, do: 0, else: state.scroll
    scroll = max(scroll + delta, 0)
    {%{state | scroll: scroll}, [{:scrolled, scroll}]}
  end

  defp focus(%{elements: []} = state, _delta), do: {state, []}

  defp focus(state, delta) do
    focused = rem(state.focused + delta + length(state.elements), length(state.elements))
    element = Enum.at(state.elements, focused)
    {%{state | focused: focused, scroll: element.start_line}, [{:focused, element}]}
  end

  defp copy_focused(state) do
    case Enum.at(state.elements, state.focused) do
      nil -> {state, []}
      element -> {state, [{:copy, element.content}]}
    end
  end
end
