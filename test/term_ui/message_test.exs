defmodule TermUI.MessageTest do
  use ExUnit.Case, async: true

  alias TermUI.Message

  describe "valid?/1" do
    test "atoms are valid messages" do
      assert Message.valid?(:increment)
      assert Message.valid?(:submit)
    end

    test "nil is not a valid message" do
      refute Message.valid?(nil)
    end

    test "tuples with at least one element are valid" do
      assert Message.valid?({:select})
      assert Message.valid?({:select, 3})
      assert Message.valid?({:update, :name, "value"})
    end

    test "structs are valid messages" do
      assert Message.valid?(%{__struct__: MyMsg})
    end

    test "other types are not valid" do
      refute Message.valid?("string")
      refute Message.valid?(123)
      refute Message.valid?([])
    end
  end

  describe "name/1" do
    test "returns atom for atom messages" do
      assert Message.name(:increment) == :increment
    end

    test "returns first element for tuple messages" do
      assert Message.name({:select, 3}) == :select
      assert Message.name({:update, :name, "value"}) == :update
    end

    test "returns module for struct messages" do
      assert Message.name(%{__struct__: MyMsg}) == MyMsg
    end
  end

  describe "payload/1" do
    test "returns nil for atom messages" do
      assert Message.payload(:increment) == nil
    end

    test "returns nil for single-element tuples" do
      assert Message.payload({:submit}) == nil
    end

    test "returns second element for 2-element tuples" do
      assert Message.payload({:select, 3}) == 3
    end

    test "returns list for longer tuples" do
      assert Message.payload({:update, :name, "value"}) == [:name, "value"]
    end

    test "returns struct itself for struct messages" do
      msg = %{__struct__: MyMsg, value: 42}
      assert Message.payload(msg) == msg
    end
  end

  describe "wrap/1" do
    test "wraps message in tuple" do
      assert Message.wrap(:increment) == {:msg, :increment}
      assert Message.wrap({:select, 3}) == {:msg, {:select, 3}}
    end
  end

  describe "type predicates" do
    test "atom?/1 returns true for atoms" do
      assert Message.atom?(:increment)
      refute Message.atom?({:select, 3})
      refute Message.atom?(nil)
    end

    test "tuple?/1 returns true for tuples" do
      assert Message.tuple?({:select, 3})
      refute Message.tuple?(:increment)
    end

    test "struct?/1 returns true for structs" do
      assert Message.struct?(%{__struct__: MyMsg})
      refute Message.struct?(:increment)
    end
  end

  describe "match?/2" do
    test "matches atom messages" do
      assert Message.match?(:submit, :submit)
      refute Message.match?(:submit, :cancel)
    end

    test "matches tuple messages by first element" do
      assert Message.match?({:select, 3}, :select)
      refute Message.match?({:select, 3}, :update)
    end

    test "matches struct messages by module" do
      assert Message.match?(%{__struct__: MyMsg}, MyMsg)
      refute Message.match?(%{__struct__: MyMsg}, OtherMsg)
    end
  end
end
