defmodule TermUI.Error do
  @moduledoc """
  Standardized error types for TermUI.

  This module provides a consistent set of error types that are used throughout
  the TermUI codebase. Using standardized error types makes error handling
  more predictable and allows for better error messages to users.

  ## Error Types

  The following error types are defined:

  - `:invalid_argument` - A required argument was missing or invalid
  - `:not_found` - A requested resource was not found
  - `:not_supported` - An operation is not supported in the current context
  - `:timeout` - An operation timed out
  - `:terminal_setup_failed` - Failed to initialize the terminal
  - `:size_detection_failed` - Failed to detect terminal dimensions
  - `:invalid_size` - Terminal dimensions were invalid
  - `:out_of_bounds` - An operation exceeded valid bounds
  - `:backend_unavailable` - The requested backend is not available
  - `:command_failed` - An external command failed
  - `:command_not_found` - An external command was not found
  - `:command_not_allowed` - An external command is not in the whitelist
  - `:invalid_configuration` - Application configuration is invalid
  - `:component_crashed` - A component process crashed
  - `:component_unavailable` - A component is not available

  ## Usage

  When returning errors from functions, use these standardized reasons:

      def init(opts) do
        case Keyword.get(opts, :size) do
          nil -> {:error, {:invalid_size, "size is required"}}
          size when is_integer(size) and size > 0 -> {:ok, size}
          _ -> {:error, {:invalid_size, "size must be a positive integer"}}
        end
      end

  ## Error Reasons

  Error reasons are either:
  - An atom from the list above (simple error)
  - A tuple `{error_type, details}` (error with additional context)

  ## Examples

      {:error, :not_found}
      {:error, {:invalid_size, "dimensions must be positive"}}
      {:error, {:command_failed, {:exit_code, 1}}}
  """

  @type error_reason ::
          :invalid_argument
          | :not_found
          | :not_supported
          | :timeout
          | :terminal_setup_failed
          | :size_detection_failed
          | :invalid_size
          | :out_of_bounds
          | :backend_unavailable
          | :command_failed
          | :command_not_found
          | :command_not_allowed
          | :invalid_configuration
          | :component_crashed
          | :component_unavailable
          | {atom(), term()}

  @type result :: {:ok, term()} | {:error, error_reason()}

  @doc """
  Formats an error reason into a human-readable string.

  ## Examples

      iex> TermUI.Error.format(:not_found)
      "not found"

      iex> TermUI.Error.format({:invalid_size, "must be positive"})
      "invalid size: must be positive"

      iex> TermUI.Error.format({:command_failed, {:exit_code, 1}})
      "command failed: {:exit_code, 1}"
  """
  @spec format(error_reason()) :: String.t()
  def format(:invalid_argument), do: "invalid argument"
  def format(:not_found), do: "not found"
  def format(:not_supported), do: "not supported"
  def format(:timeout), do: "operation timed out"
  def format(:terminal_setup_failed), do: "terminal setup failed"
  def format(:size_detection_failed), do: "failed to detect terminal size"
  def format(:invalid_size), do: "invalid size"
  def format(:out_of_bounds), do: "out of bounds"
  def format(:backend_unavailable), do: "backend unavailable"
  def format(:command_failed), do: "command failed"
  def format(:command_not_found), do: "command not found"
  def format(:command_not_allowed), do: "command not allowed"
  def format(:invalid_configuration), do: "invalid configuration"
  def format(:component_crashed), do: "component crashed"
  def format(:component_unavailable), do: "component unavailable"

  def format({type, details}) when is_binary(details) do
    "#{format(type)}: #{details}"
  end

  def format({type, details}) do
    "#{format(type)}: #{inspect(details)}"
  end

  @doc """
  Creates an error reason with details.

  ## Examples

      iex> TermUI.Error.error(:invalid_size, "dimensions must be positive")
      {:invalid_size, "dimensions must be positive"}

  """
  @spec error(atom(), term()) :: error_reason()
  def error(type, details), do: {type, details}

  @doc """
  Returns true if the given term is an error reason.

  ## Examples

      iex> TermUI.Error.error_reason?(:not_found)
      true

      iex> TermUI.Error.error_reason?({:invalid_size, "too small"})
      true

      iex> TermUI.Error.error_reason?(:ok)
      false

      iex> TermUI.Error.error_reason?({:ok, "result"})
      false

  """
  @spec error_reason?(term()) :: boolean()
  def error_reason?(:invalid_argument), do: true
  def error_reason?(:not_found), do: true
  def error_reason?(:not_supported), do: true
  def error_reason?(:timeout), do: true
  def error_reason?(:terminal_setup_failed), do: true
  def error_reason?(:size_detection_failed), do: true
  def error_reason?(:invalid_size), do: true
  def error_reason?(:out_of_bounds), do: true
  def error_reason?(:backend_unavailable), do: true
  def error_reason?(:command_failed), do: true
  def error_reason?(:command_not_found), do: true
  def error_reason?(:command_not_allowed), do: true
  def error_reason?(:invalid_configuration), do: true
  def error_reason?(:component_crashed), do: true
  def error_reason?(:component_unavailable), do: true

  def error_reason?({type, _}) when is_atom(type) do
    error_reason?(type)
  end

  def error_reason?(_), do: false

  @doc """
  Returns the error type from an error reason.

  For simple error reasons (atoms), returns the atom itself.
  For tuple error reasons, returns the first element (the type).

  ## Examples

      iex> TermUI.Error.error_type(:not_found)
      :not_found

      iex> TermUI.Error.error_type({:invalid_size, "too small"})
      :invalid_size

  """
  @spec error_type(error_reason()) :: atom()
  def error_type({type, _}), do: type
  def error_type(type), do: type
end
