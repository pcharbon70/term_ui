defmodule Showcase.App do
  @moduledoc "The interactive TermUI widget and architecture showcase."

  use TermUI.Elm

  alias TermUI.Event.{Key, Resize}
  alias TermUI.{Clipboard, Command, Frame, Style}
  alias Showcase.Pages.{Architecture, Beam, Content, Inputs, Overview}

  @tick_interval 500
  @pages [
    {:overview, "Overview", Overview},
    {:inputs, "Inputs", Inputs},
    {:content, "Content", Content},
    {:beam, "BEAM", Beam},
    {:architecture, "Architecture", Architecture}
  ]

  @impl true
  def init(opts) do
    page_states = Map.new(@pages, fn {id, _label, module} -> {id, module.init()} end)

    state = %{
      dimensions: Keyword.fetch!(opts, :dimensions),
      page: :overview,
      page_states: page_states,
      theme: :dark,
      status: "F1-F5 select a page"
    }

    {state, [Command.timer(@tick_interval, :tick)]}
  end

  @impl true
  def event_to_msg(%Resize{width: width, height: height}, _state),
    do: {:msg, {:resize, width, height}}

  def event_to_msg(%Key{key: key}, _state) when key in [:f1, :f2, :f3, :f4, :f5],
    do: {:msg, {:select_page, page_for_key(key)}}

  def event_to_msg(%Key{key: :f9}, _state), do: {:msg, :toggle_theme}
  def event_to_msg(%Key{key: key}, _state) when key in [:f10, :escape], do: {:msg, :quit}

  def event_to_msg(%Key{key: key, modifiers: modifiers} = event, _state)
      when key in ["n", "p", "q", "t"] do
    if :ctrl in modifiers,
      do: {:msg, control_message(key)},
      else: {:msg, {:page_event, event}}
  end

  def event_to_msg(event, _state), do: {:msg, {:page_event, event}}

  @impl true
  def update({:resize, width, height}, state),
    do: %{state | dimensions: {width, height}, status: "Terminal resized to #{width}x#{height}"}

  def update({:select_page, page}, state), do: select_page(state, page)
  def update(:next_page, state), do: move_page(state, 1)
  def update(:previous_page, state), do: move_page(state, -1)
  def update(:toggle_theme, state), do: toggle_theme(state)
  def update(:quit, state), do: {state, [Command.shutdown()]}

  def update(:tick, state) do
    {state, _messages} = update_current_page(state, :tick)
    {state, [Command.timer(@tick_interval, :tick)]}
  end

  def update({:page_event, event}, state) do
    {state, messages} = update_current_page(state, event)
    apply_page_messages(state, messages)
  end

  def update({:clipboard_result, :ok}, state), do: %{state | status: "Copied to clipboard"}

  def update({:clipboard_result, {:error, reason}}, state),
    do: %{state | status: "Clipboard error: #{inspect(reason)}"}

  @impl true
  def view(%{dimensions: {width, height}} = state) do
    if height < 4 do
      Frame.from_rows([[{" TermUI Showcase ", header_style(state.theme)}]], width, height)
    else
      {_id, label, module} = current_page(state)
      content_height = height - 3

      content =
        module.view(
          Map.fetch!(state.page_states, state.page),
          {width, content_height},
          state.theme
        )

      Frame.new(width, height)
      |> Frame.put_row(1, header_row(label, state.theme))
      |> Frame.put_row(2, page_row(state.page, state.theme))
      |> Frame.put_row(height, footer_row(state.status, width))
      |> Frame.overlay(content, 1, 3)
    end
  end

  @doc "Runs the showcase in the current terminal."
  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []), do: TermUI.run(__MODULE__, opts)

  @doc false
  def pages, do: @pages

  defp update_current_page(state, event) do
    {_id, _label, module} = current_page(state)
    page_state = Map.fetch!(state.page_states, state.page)
    {page_state, messages} = module.update(event, page_state)
    {%{state | page_states: Map.put(state.page_states, state.page, page_state)}, messages}
  end

  defp apply_page_messages(state, messages) do
    {commands, status} =
      Enum.reduce(messages, {[], nil}, fn
        {:copy, text}, {commands, _status} ->
          {[Clipboard.copy(text) | commands], "Copy requested"}

        message, {commands, _status} ->
          {commands, format_message(message)}
      end)

    state = if status, do: %{state | status: status}, else: state
    if commands == [], do: state, else: {state, Enum.reverse(commands)}
  end

  defp current_page(state),
    do: Enum.find(@pages, fn {id, _label, _module} -> id == state.page end)

  defp select_page(state, page) do
    case Enum.find(@pages, fn {id, _label, _module} -> id == page end) do
      nil -> state
      {_id, label, module} -> %{state | page: page, status: label <> ": " <> module.help()}
    end
  end

  defp move_page(state, delta) do
    ids = Enum.map(@pages, &elem(&1, 0))
    index = Enum.find_index(ids, &(&1 == state.page)) || 0
    next = rem(index + delta + length(ids), length(ids))
    select_page(state, Enum.at(ids, next))
  end

  defp toggle_theme(state) do
    theme = if state.theme == :dark, do: :light, else: :dark
    %{state | theme: theme, status: "Theme: #{theme}"}
  end

  defp header_row(label, theme) do
    [
      {" TermUI Showcase ", header_style(theme)},
      {" " <> label, Style.new(fg: accent(theme), attrs: [:bold])}
    ]
  end

  defp page_row(selected, theme) do
    @pages
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {{id, label, _module}, index} ->
      style =
        if id == selected,
          do: Style.new(fg: :black, bg: accent(theme), attrs: [:bold]),
          else: Style.new(fg: :bright_black)

      [{" F#{index} #{label} ", style}, " "]
    end)
  end

  defp footer_row(status, width) do
    controls = "F1-F5 page  F9 theme  F10/Esc quit"
    available = max(width - String.length(controls) - 1, 0)

    [
      {Frame.fit(status, available), Style.new(fg: :bright_black)},
      {controls, Style.new(fg: :cyan)}
    ]
  end

  defp header_style(:light), do: Style.new(fg: :white, bg: :blue, attrs: [:bold])
  defp header_style(:dark), do: Style.new(fg: :black, bg: :cyan, attrs: [:bold])
  defp accent(:light), do: :blue
  defp accent(:dark), do: :cyan

  defp page_for_key(:f1), do: :overview
  defp page_for_key(:f2), do: :inputs
  defp page_for_key(:f3), do: :content
  defp page_for_key(:f4), do: :beam
  defp page_for_key(:f5), do: :architecture

  defp control_message("n"), do: :next_page
  defp control_message("p"), do: :previous_page
  defp control_message("q"), do: :quit
  defp control_message("t"), do: :toggle_theme

  defp format_message({kind, value}) when kind in [:changed, :submit, :selected, :picked],
    do: "#{kind}: #{inspect(value, limit: 3)}"

  defp format_message(message), do: inspect(message, limit: 4)
end
