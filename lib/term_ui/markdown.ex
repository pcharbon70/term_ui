defmodule TermUI.Markdown do
  @moduledoc """
  Markdown processor for rendering styled text in TermUI.

  Converts markdown content to styled segments that can be rendered
  by TermUI components.

  ## Usage

      iex> lines = TermUI.Markdown.render("**bold** and *italic*", 80)

      iex> result = TermUI.Markdown.render_with_elements("```elixir\\ndef hello, do: :world\\n```", 80)
  """

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  @type styled_segment :: {String.t(), Style.t() | nil}
  @type styled_line :: [styled_segment]

  @type interactive_element :: %{
          id: String.t(),
          type: :code_block,
          content: String.t(),
          language: String.t() | nil,
          start_line: non_neg_integer(),
          end_line: non_neg_integer()
        }

  @type render_result :: %{
          lines: [styled_line()],
          elements: [interactive_element()],
          content_height: non_neg_integer()
        }

  # Style definitions
  @header1_style Style.new(fg: :cyan, attrs: [:bold])
  @header2_style Style.new(fg: :cyan, attrs: [:bold])
  @header3_style Style.new(fg: :white, attrs: [:bold])
  @bold_style Style.new(attrs: [:bold])
  @italic_style Style.new(attrs: [:italic])
  @code_style Style.new(fg: :yellow)
  @code_block_style Style.new(fg: :yellow)
  @code_border_style Style.new(fg: :bright_black)
  @code_border_focused_style Style.new(fg: :cyan, attrs: [:bold])
  @blockquote_style Style.new(fg: :bright_black)
  @link_style Style.new(fg: :blue, attrs: [:underline])
  @list_bullet_style Style.new(fg: :cyan)
  @hr_style Style.new(fg: :bright_black)

  # Syntax highlighting token styles
  @token_styles %{
    keyword: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_namespace: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_pseudo: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_reserved: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_constant: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_declaration: Style.new(fg: :magenta, attrs: [:bold]),
    keyword_type: Style.new(fg: :magenta, attrs: [:bold]),
    string: Style.new(fg: :green),
    string_char: Style.new(fg: :green),
    string_doc: Style.new(fg: :green),
    string_double: Style.new(fg: :green),
    string_single: Style.new(fg: :green),
    string_sigil: Style.new(fg: :green),
    string_regex: Style.new(fg: :green),
    string_interpol: Style.new(fg: :red),
    string_escape: Style.new(fg: :cyan),
    string_symbol: Style.new(fg: :cyan),
    comment: Style.new(fg: :bright_black),
    comment_single: Style.new(fg: :bright_black),
    comment_multiline: Style.new(fg: :bright_black),
    comment_doc: Style.new(fg: :bright_black),
    atom: Style.new(fg: :cyan),
    number: Style.new(fg: :yellow),
    number_integer: Style.new(fg: :yellow),
    number_float: Style.new(fg: :yellow),
    number_bin: Style.new(fg: :yellow),
    number_oct: Style.new(fg: :yellow),
    number_hex: Style.new(fg: :yellow),
    operator: Style.new(fg: :yellow),
    operator_word: Style.new(fg: :magenta, attrs: [:bold]),
    name: Style.new(fg: :white),
    name_function: Style.new(fg: :blue),
    name_class: Style.new(fg: :yellow, attrs: [:bold]),
    name_builtin: Style.new(fg: :cyan),
    name_builtin_pseudo: Style.new(fg: :cyan),
    name_attribute: Style.new(fg: :cyan),
    name_label: Style.new(fg: :cyan),
    name_constant: Style.new(fg: :yellow, attrs: [:bold]),
    name_exception: Style.new(fg: :red),
    name_tag: Style.new(fg: :blue),
    name_decorator: Style.new(fg: :cyan),
    name_namespace: Style.new(fg: :yellow, attrs: [:bold]),
    punctuation: Style.new(fg: :white),
    whitespace: nil,
    text: nil
  }

  @supported_lexers %{
    "elixir" => Makeup.Lexers.ElixirLexer,
    "ex" => Makeup.Lexers.ElixirLexer,
    "exs" => Makeup.Lexers.ElixirLexer,
    "iex" => Makeup.Lexers.ElixirLexer,
    "erlang" => Makeup.Lexers.ErlangLexer,
    "erl" => Makeup.Lexers.ErlangLexer,
    "hrl" => Makeup.Lexers.ErlangLexer
  }

  @doc """
  Renders markdown content as a list of styled lines.
  """
  @spec render(String.t(), pos_integer()) :: [styled_line()]
  def render("", _max_width), do: [[{"", nil}]]
  def render(nil, _max_width), do: [[{"", nil}]]

  def render(content, max_width) when is_binary(content) and max_width > 0 do
    case MDEx.parse_document(content) do
      {:ok, document} ->
        document
        |> process_document()
        |> wrap_styled_lines(max_width)

      {:error, _reason} ->
        content
        |> String.split("\n")
        |> Enum.map(fn line -> [{line, nil}] end)
        |> wrap_styled_lines(max_width)
    end
  end

  def render(content, _max_width) when is_binary(content), do: render(content, 80)

  @doc """
  Renders markdown content with interactive element tracking.
  """
  @spec render_with_elements(String.t(), pos_integer(), keyword()) :: render_result()
  def render_with_elements("", _max_width, _opts) do
    %{lines: [[{"", nil}]], elements: [], content_height: 1}
  end

  def render_with_elements(nil, _max_width, _opts) do
    %{lines: [[{"", nil}]], elements: [], content_height: 1}
  end

  def render_with_elements(content, max_width, opts) when is_binary(content) and max_width > 0 do
    focused_id = Keyword.get(opts, :focused_element_id)

    case MDEx.parse_document(content) do
      {:ok, document} ->
        {raw_lines, elements} = process_document_with_elements(document, focused_id)
        wrapped_lines = wrap_styled_lines(raw_lines, max_width)
        %{lines: wrapped_lines, elements: elements, content_height: length(wrapped_lines)}

      {:error, _reason} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.map(fn line -> [{line, nil}] end)
          |> wrap_styled_lines(max_width)

        %{lines: lines, elements: [], content_height: length(lines)}
    end
  end

  def render_with_elements(content, _max_width, opts) when is_binary(content) do
    render_with_elements(content, 80, opts)
  end

  @doc """
  Converts a styled line to a TermUI render node.
  """
  @spec render_line_to_node(styled_line()) :: RenderNode.t()
  def render_line_to_node([]), do: RenderNode.text("", nil)

  def render_line_to_node([{text, style}]) do
    RenderNode.text(text, style)
  end

  def render_line_to_node(segments) when is_list(segments) do
    nodes =
      Enum.map(segments, fn {text, style} ->
        RenderNode.text(text, style)
      end)

    RenderNode.stack(:horizontal, nodes)
  end

  # Document Processing
  defp process_document(%MDEx.Document{nodes: nodes}) do
    Enum.flat_map(nodes, &process_node/1)
  end

  defp process_document_with_elements(%MDEx.Document{nodes: nodes}, focused_id) do
    {lines, elements, _line_idx} =
      Enum.reduce(nodes, {[], [], 0}, fn node, {acc_lines, acc_elements, line_idx} ->
        {node_lines, node_elements} = process_node_with_elements(node, line_idx, focused_id)
        new_line_idx = line_idx + length(node_lines)
        {acc_lines ++ node_lines, acc_elements ++ node_elements, new_line_idx}
      end)

    {lines, elements}
  end

  defp process_node_with_elements(
         %MDEx.CodeBlock{literal: code, info: info},
         line_idx,
         focused_id
       ) do
    lang = if info && info != "", do: String.downcase(String.trim(info)), else: nil
    element_id = generate_element_id(code, line_idx)
    is_focused = element_id == focused_id
    border_style = if is_focused, do: @code_border_focused_style, else: @code_border_style

    header =
      if lang do
        focus_hint = if is_focused, do: " [c]", else: ""

        [
          [
            {"┌─ " <> lang <> focus_hint <> " ", @code_block_style},
            {String.duplicate("─", 40 - String.length(focus_hint)), border_style}
          ]
        ]
      else
        focus_hint = if is_focused, do: " [c]", else: ""

        [
          [
            {"┌" <> focus_hint, @code_block_style},
            {String.duplicate("─", 44 - String.length(focus_hint)), border_style}
          ]
        ]
      end

    code_lines = render_code_block(code, lang)
    footer = [[{"└", @code_block_style}, {String.duplicate("─", 44), border_style}], [{"", nil}]]

    lines = header ++ code_lines ++ footer

    element = %{
      id: element_id,
      type: :code_block,
      content: String.trim_trailing(code),
      language: lang,
      start_line: line_idx,
      end_line: line_idx + length(lines) - 1
    }

    {lines, [element]}
  end

  defp process_node_with_elements(node, _line_idx, _focused_id) do
    lines = process_node(node)
    {lines, []}
  end

  defp generate_element_id(content, line_idx) do
    :crypto.hash(:md5, "#{line_idx}:#{content}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  # Node Processing
  defp process_node(%MDEx.Heading{level: 1, nodes: children}) do
    content = extract_text(children)
    [[{"# " <> content, @header1_style}], [{"", nil}]]
  end

  defp process_node(%MDEx.Heading{level: 2, nodes: children}) do
    content = extract_text(children)
    [[{"## " <> content, @header2_style}], [{"", nil}]]
  end

  defp process_node(%MDEx.Heading{level: level, nodes: children}) when level >= 3 do
    prefix = String.duplicate("#", level) <> " "
    content = extract_text(children)
    [[{prefix <> content, @header3_style}], [{"", nil}]]
  end

  defp process_node(%MDEx.Paragraph{nodes: children}) do
    segments = process_inline_nodes(children)
    [segments, [{"", nil}]]
  end

  defp process_node(%MDEx.CodeBlock{literal: code, info: info}) do
    lang = if info && info != "", do: String.downcase(String.trim(info)), else: nil

    header =
      if lang do
        [
          [
            {"┌─ " <> lang <> " ", @code_block_style},
            {String.duplicate("─", 40), @code_border_style}
          ]
        ]
      else
        [[{"┌", @code_block_style}, {String.duplicate("─", 44), @code_border_style}]]
      end

    code_lines = render_code_block(code, lang)

    footer = [
      [{"└", @code_block_style}, {String.duplicate("─", 44), @code_border_style}],
      [{"", nil}]
    ]

    header ++ code_lines ++ footer
  end

  defp process_node(%MDEx.Code{literal: code}) do
    [[{"`" <> code <> "`", @code_style}]]
  end

  defp process_node(%MDEx.BlockQuote{nodes: children}) do
    children
    |> Enum.flat_map(&process_node/1)
    |> Enum.map(fn segments ->
      case segments do
        [{text, _style} | rest] ->
          [{"│ " <> text, @blockquote_style} | rest]

        [] ->
          [{"│ ", @blockquote_style}]
      end
    end)
  end

  defp process_node(%MDEx.List{list_type: :bullet, nodes: items}) do
    items
    |> Enum.flat_map(fn item ->
      process_list_item(item, "• ")
    end)
    |> Kernel.++([[{"", nil}]])
  end

  defp process_node(%MDEx.List{list_type: :ordered, nodes: items, start: start}) do
    items
    |> Enum.with_index(start || 1)
    |> Enum.flat_map(fn {item, idx} ->
      process_list_item(item, "#{idx}. ")
    end)
    |> Kernel.++([[{"", nil}]])
  end

  defp process_node(%MDEx.ListItem{nodes: children}) do
    Enum.flat_map(children, &process_node/1)
  end

  defp process_node(%MDEx.ThematicBreak{}) do
    [[{"───────────────────────────────────────", @hr_style}], [{"", nil}]]
  end

  defp process_node(%MDEx.SoftBreak{}), do: []
  defp process_node(%MDEx.LineBreak{}), do: [[{"", nil}]]

  defp process_node(node) when is_map(node) do
    case Map.get(node, :nodes) do
      nil ->
        case Map.get(node, :literal) do
          nil -> []
          text -> [[{text, nil}]]
        end

      children ->
        Enum.flat_map(children, &process_node/1)
    end
  end

  defp process_node(_), do: []

  # Code Block Rendering
  defp render_code_block(code, lang) do
    case Map.get(@supported_lexers, lang) do
      nil ->
        plain_code_lines(code)

      lexer ->
        try do
          highlighted_code_lines(code, lexer)
        rescue
          _ -> plain_code_lines(code)
        end
    end
  end

  defp plain_code_lines(code) do
    code
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map(fn line -> [{"│ " <> line, @code_block_style}] end)
  end

  defp highlighted_code_lines(code, lexer) do
    tokens = lexer.lex(code |> String.trim_trailing())

    {lines, current_line} =
      Enum.reduce(tokens, {[], []}, fn {type, _meta, text}, {lines, current} ->
        style = Map.get(@token_styles, type) || @code_block_style
        text_str = normalize_token_text(text)
        add_token_to_lines(text_str, style, lines, current)
      end)

    all_lines = finalize_code_lines(lines, current_line)

    Enum.map(all_lines, fn segments ->
      [{"│ ", @code_block_style} | segments]
    end)
  end

  defp add_token_to_lines(text, style, lines, current) do
    parts = String.split(text, "\n")

    case parts do
      [single] ->
        {lines, current ++ [{single, style}]}

      [first | rest] ->
        finished_line = current ++ [{first, style}]
        {middle_parts, [last]} = Enum.split(rest, -1)
        middle_lines = Enum.map(middle_parts, fn part -> [{part, style}] end)
        {lines ++ [finished_line] ++ middle_lines, [{last, style}]}
    end
  end

  defp finalize_code_lines(lines, []), do: lines
  defp finalize_code_lines(lines, current), do: lines ++ [current]

  defp normalize_token_text(text) when is_binary(text), do: text

  defp normalize_token_text(text) when is_list(text) do
    text
    |> List.flatten()
    |> Enum.map_join(fn
      char when is_integer(char) -> <<char::utf8>>
      str when is_binary(str) -> str
    end)
  end

  defp normalize_token_text(text), do: to_string(text)

  # Inline Node Processing
  defp process_inline_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.flat_map(&process_inline_node/1)
    |> merge_adjacent_segments()
  end

  defp process_inline_node(%MDEx.Text{literal: text}), do: [{text, nil}]

  defp process_inline_node(%MDEx.Strong{nodes: children}) do
    text = extract_text(children)
    [{text, @bold_style}]
  end

  defp process_inline_node(%MDEx.Emph{nodes: children}) do
    text = extract_text(children)
    [{text, @italic_style}]
  end

  defp process_inline_node(%MDEx.Code{literal: code}) do
    [{"`" <> code <> "`", @code_style}]
  end

  defp process_inline_node(%MDEx.Link{url: url, nodes: children}) do
    text = extract_text(children)

    if text == url do
      [{text, @link_style}]
    else
      [{text, @link_style}, {" (#{url})", Style.new(fg: :bright_black)}]
    end
  end

  defp process_inline_node(%MDEx.SoftBreak{}), do: [{" ", nil}]
  defp process_inline_node(%MDEx.LineBreak{}), do: [{"\n", nil}]

  defp process_inline_node(node) when is_map(node) do
    case Map.get(node, :literal) do
      nil ->
        case Map.get(node, :nodes) do
          nil -> []
          children -> process_inline_nodes(children)
        end

      text ->
        [{text, nil}]
    end
  end

  defp process_inline_node(_), do: []

  # List Processing
  defp process_list_item(%MDEx.ListItem{nodes: children}, prefix) do
    children
    |> Enum.flat_map(&process_node/1)
    |> Enum.with_index()
    |> Enum.map(fn {segments, idx} ->
      format_list_item_line(segments, idx, prefix)
    end)
    |> Enum.reject(fn segments ->
      segments == [{"", nil}]
    end)
  end

  defp format_list_item_line(segments, 0, prefix) do
    prepend_list_bullet(segments, prefix)
  end

  defp format_list_item_line(segments, _idx, prefix) do
    indent = String.duplicate(" ", String.length(prefix))
    indent_continuation_line(segments, indent)
  end

  defp prepend_list_bullet([{text, style} | rest], prefix) do
    [{prefix, @list_bullet_style}, {text, style} | rest]
  end

  defp prepend_list_bullet([], prefix) do
    [{prefix, @list_bullet_style}]
  end

  defp indent_continuation_line([{text, style} | rest], indent) do
    [{indent <> text, style} | rest]
  end

  defp indent_continuation_line([], _indent), do: []

  # Text Extraction
  defp extract_text(nodes) when is_list(nodes) do
    Enum.map_join(nodes, &extract_text/1)
  end

  defp extract_text(%{literal: text}) when is_binary(text), do: text
  defp extract_text(%{nodes: children}), do: extract_text(children)
  defp extract_text(_), do: ""

  # Segment Merging
  defp merge_adjacent_segments([]), do: []

  defp merge_adjacent_segments(segments) do
    segments
    |> Enum.reduce([], fn {text, style}, acc ->
      case acc do
        [{prev_text, ^style} | rest] ->
          [{prev_text <> text, style} | rest]

        _ ->
          [{text, style} | acc]
      end
    end)
    |> Enum.reverse()
  end

  # Line Wrapping
  @spec wrap_styled_lines([styled_line()], pos_integer()) :: [styled_line()]
  def wrap_styled_lines(lines, max_width) do
    lines
    |> Enum.flat_map(fn line ->
      wrap_styled_line(line, max_width)
    end)
  end

  defp wrap_styled_line([], _max_width), do: [[]]

  defp wrap_styled_line(segments, max_width) do
    expanded_segments =
      segments
      |> Enum.flat_map(&expand_segment_newlines/1)

    {current, wrapped} =
      Enum.reduce(expanded_segments, {[], []}, fn
        :newline, {current, acc} ->
          {[], acc ++ [Enum.reverse(current)]}

        segment, {current, acc} ->
          {[segment | current], acc}
      end)

    lines_from_newlines = wrapped ++ [Enum.reverse(current)]

    lines_from_newlines
    |> Enum.flat_map(fn line_segments ->
      wrap_segments_for_width(line_segments, max_width)
    end)
  end

  defp expand_segment_newlines({text, style}) do
    if String.contains?(text, "\n") do
      text
      |> String.split("\n")
      |> Enum.intersperse(:newline)
      |> Enum.map(&tag_newline_or_text(&1, style))
    else
      [{text, style}]
    end
  end

  defp tag_newline_or_text(:newline, _style), do: :newline
  defp tag_newline_or_text(text, style), do: {text, style}

  defp wrap_segments_for_width([], _max_width), do: [[]]

  defp wrap_segments_for_width(segments, max_width) do
    {lines, current_line, _current_width} =
      Enum.reduce(segments, {[], [], 0}, fn {text, style}, {lines, current, width} ->
        wrap_segment({text, style}, lines, current, width, max_width)
      end)

    all_lines = lines ++ [current_line]

    all_lines
    |> Enum.map(fn line ->
      case line do
        [] -> [{"", nil}]
        segments -> segments
      end
    end)
  end

  defp wrap_segment({text, style}, lines, current, width, max_width) do
    text_len = String.length(text)

    cond do
      text == "" ->
        {lines, current ++ [{text, style}], width}

      width + text_len <= max_width ->
        {lines, current ++ [{text, style}], width + text_len}

      true ->
        wrap_text_at_words(text, style, lines, current, width, max_width)
    end
  end

  defp wrap_text_at_words(text, style, lines, current, width, max_width) do
    words = String.split(text, ~r/(\s+)/, include_captures: true)

    {final_lines, final_current, final_width} =
      Enum.reduce(words, {lines, current, width}, fn word, {ls, cur, w} ->
        wrap_word(word, style, ls, cur, w, max_width)
      end)

    {final_lines, final_current, final_width}
  end

  defp wrap_word("", _style, lines, current, width, _max_width) do
    {lines, current, width}
  end

  defp wrap_word(word, style, lines, current, width, max_width) do
    word_len = String.length(word)

    cond do
      width + word_len <= max_width ->
        {lines, current ++ [{word, style}], width + word_len}

      word_len > max_width ->
        wrap_long_word(word, style, lines, current, width, max_width)

      String.trim(word) == "" ->
        {lines, current, width}

      true ->
        {lines ++ [current], [{word, style}], word_len}
    end
  end

  defp wrap_long_word(word, style, lines, [], _width, max_width) do
    {new_lines, remainder} = break_long_word(word, style, max_width, max_width)
    {lines ++ new_lines, [{remainder, style}], String.length(remainder)}
  end

  defp wrap_long_word(word, style, lines, current, width, max_width) do
    {new_lines, remainder} = break_long_word(word, style, max_width - width, max_width)
    {lines ++ [current] ++ new_lines, [{remainder, style}], String.length(remainder)}
  end

  defp break_long_word(word, style, first_chunk_size, max_width) do
    first_chunk_size = max(first_chunk_size, 1)

    chunks =
      word
      |> String.graphemes()
      |> Enum.chunk_every(max_width)
      |> Enum.map(&Enum.join/1)

    case chunks do
      [] ->
        {[], ""}

      [only] ->
        {[], only}

      [first | rest] ->
        first_part = String.slice(first, 0, first_chunk_size)
        remainder_of_first = String.slice(first, first_chunk_size..-1//1)

        all_parts = [remainder_of_first | rest]

        lines =
          all_parts
          |> Enum.slice(0..-2//1)
          |> Enum.map(fn part -> [{part, style}] end)

        last = List.last(all_parts) || ""

        if first_part == "" do
          {lines, last}
        else
          {[[{first_part, style}]] ++ lines, last}
        end
    end
  end
end
