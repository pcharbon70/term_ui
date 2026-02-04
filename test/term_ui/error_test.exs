defmodule TermUI.ErrorTest do
  use TermUI.TestCase
  doctest TermUI.Error

  alias TermUI.Error

  describe "format/1" do
    test "formats simple error atoms" do
      assert Error.format(:not_found) == "not found"
      assert Error.format(:timeout) == "operation timed out"
      assert Error.format(:invalid_size) == "invalid size"
    end

    test "formats tuple errors with string details" do
      assert Error.format({:invalid_size, "must be positive"}) ==
               "invalid size: must be positive"

      assert Error.format({:command_failed, "exit code 1"}) ==
               "command failed: exit code 1"
    end

    test "formats tuple errors with non-string details" do
      assert Error.format({:command_failed, {:exit_code, 1}}) =~
               "command failed:"

      assert Error.format({:invalid_size, {24, 80}}) =~
               "invalid size:"
    end
  end

  describe "error/2" do
    test "creates error tuple with details" do
      assert Error.error(:invalid_size, "too small") == {:invalid_size, "too small"}
      assert Error.error(:command_failed, {:exit_code, 1}) == {:command_failed, {:exit_code, 1}}
    end
  end

  describe "error_reason?/1" do
    test "returns true for valid error atoms" do
      assert Error.error_reason?(:not_found)
      assert Error.error_reason?(:timeout)
      assert Error.error_reason?(:invalid_size)
      assert Error.error_reason?(:component_crashed)
    end

    test "returns true for valid error tuples" do
      assert Error.error_reason?({:not_found, "resource"})
      assert Error.error_reason?({:invalid_size, {24, 80}})
      assert Error.error_reason?({:command_failed, {:exit_code, 1}})
    end

    test "returns false for non-error atoms" do
      refute Error.error_reason?(:ok)
      refute Error.error_reason?(:error)
      refute Error.error_reason?(:some_atom)
    end

    test "returns false for non-error tuples" do
      refute Error.error_reason?({:ok, "result"})
      refute Error.error_reason?({:error, "message"})
      refute Error.error_reason?({1, 2, 3})
    end

    test "returns false for other types" do
      refute Error.error_reason?("string")
      refute Error.error_reason?(123)
      refute Error.error_reason?(%{})
    end
  end

  describe "error_type/1" do
    test "returns type for simple error atoms" do
      assert Error.error_type(:not_found) == :not_found
      assert Error.error_type(:timeout) == :timeout
    end

    test "returns type for error tuples" do
      assert Error.error_type({:not_found, "resource"}) == :not_found
      assert Error.error_type({:invalid_size, {24, 80}}) == :invalid_size
      assert Error.error_type({:command_failed, {:exit_code, 1}}) == :command_failed
    end
  end

  describe "type definitions" do
    test "error_reason type includes all expected atoms" do
      # These are compile-time checks that the types exist
      # If any error reason is missing, this will cause a compile error
      error_atoms = [
        :invalid_argument,
        :not_found,
        :not_supported,
        :timeout,
        :terminal_setup_failed,
        :size_detection_failed,
        :invalid_size,
        :out_of_bounds,
        :backend_unavailable,
        :command_failed,
        :command_not_found,
        :command_not_allowed,
        :invalid_configuration,
        :component_crashed,
        :component_unavailable
      ]

      # Verify these are all valid error reasons
      Enum.each(error_atoms, fn atom ->
        assert Error.error_reason?(atom), "#{atom} should be a valid error reason"
      end)
    end
  end
end
