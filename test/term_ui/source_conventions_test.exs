defmodule TermUI.SourceConventionsTest do
  use ExUnit.Case, async: true

  alias TermUI.{Cell, Command, Event, Frame, Style}
  alias TermUI.Widget.Table.Column

  @source_files Path.wildcard("lib/**/*.ex")

  test "all explicit production structs derive their shape from Zoi" do
    violations =
      Enum.flat_map(@source_files, fn path ->
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, number} ->
          if Regex.match?(~r/^\s*defstruct\b/, line) and
               not String.contains?(line, "defstruct Zoi.Struct.struct_fields(") do
            ["#{path}:#{number}"]
          else
            []
          end
        end)
      end)

    assert violations == [],
           "explicit structs must derive fields and defaults from a Zoi schema:\n" <>
             Enum.join(violations, "\n")
  end

  test "public data schemas accept valid structs" do
    values = [
      {Cell.schema(), Cell.new("A")},
      {Style.schema(), Style.new(fg: :cyan)},
      {Frame.schema(), Frame.new(20, 5)},
      {Event.schema(), Event.resize(20, 5)},
      {Command.schema(), Command.message(:ready)},
      {Column.schema(), Column.new(:name, "Name")}
    ]

    Enum.each(values, fn {schema, value} ->
      assert {:ok, ^value} = Zoi.parse(schema, value)
    end)
  end

  test "public data schemas reject invalid struct fields" do
    invalid = [
      {Cell.schema(), %Cell{width: 3}},
      {Style.schema(), %Style{attrs: MapSet.new([:unknown])}},
      {Frame.schema(), %Frame{width: 0, height: 1}},
      {Event.schema(), %Event.Resize{width: 0, height: 1}},
      {Command.schema(), %Command{kind: :unknown, value: nil}},
      {Column.schema(), %Column{key: :name, label: "Name", align: :diagonal}}
    ]

    Enum.each(invalid, fn {schema, value} ->
      assert {:error, [_error | _rest]} = Zoi.parse(schema, value)
    end)
  end

  test "normalized event constructors keep their public types and modifiers" do
    events = [
      Event.key(:enter, modifiers: [:ctrl, :ctrl], timestamp: 1),
      Event.text("x", timestamp: 2),
      Event.paste("pasted", timestamp: 3),
      Event.mouse(:press, :left, 4, 5, modifiers: [:shift, :shift], timestamp: 4),
      Event.resize(80, 24, timestamp: 5),
      Event.focus(:gained, timestamp: 6)
    ]

    assert Enum.map(events, &Event.type/1) == [:key, :text, :paste, :mouse, :resize, :focus]
    assert Event.has_modifier?(hd(events), :ctrl)
    assert hd(events).modifiers == [:ctrl]
    assert Enum.at(events, 3).modifiers == [:shift]
  end
end
