defmodule TermUI.Message do
  @moduledoc """
  Message type conventions and helpers for component messages.

  Messages are component-specific types representing meaningful actions.
  They carry semantic meaning—`{:select_item, 3}` is clearer than the raw
  key event that triggered it.

  ## Message Conventions

  Components define their own message types using one of these patterns:

  ### Simple Atom Messages

      :increment
      :decrement
      :submit
      :cancel

  ### Tuple Messages with Data

      {:select_item, 3}
      {:update_text, "hello"}
      {:set_value, 42}

  ### Struct Messages (for complex data)

      defmodule MyComponent.Msg do
        defmodule SelectItem do
          defstruct [:index, :source]
        end
      end

      %MyComponent.Msg.SelectItem{index: 3, source: :keyboard}

  ## Event to Message Conversion

  Components implement `event_to_msg/2` to convert events to messages:

      def event_to_msg(%Event.Key{key: :enter}, _state) do
        {:msg, :submit}
      end

      def event_to_msg(%Event.Key{key: :up}, _state) do
        {:msg, {:move, :up}}
      end

      def event_to_msg(_event, _state) do
        :ignore
      end

  ## Message Routing

  Messages route to the component that should handle them. The runtime
  delivers messages and components update their state in response.
  """

  @type t :: atom() | tuple() | struct()

  @doc """
  Checks if a value is a valid message.

  Messages can be atoms, tuples, or structs.
  """
  @spec valid?(term()) :: boolean()
  def valid?(msg) when is_atom(msg) and not is_nil(msg), do: true
  def valid?(msg) when is_tuple(msg) and tuple_size(msg) >= 1, do: true
  def valid?(%{__struct__: _}), do: true
  def valid?(_), do: false

  @doc """
  Returns the message type/name.

  For atoms, returns the atom itself.
  For tuples, returns the first element.
  For structs, returns the struct module name.
  """
  @spec name(t()) :: atom()
  def name(msg) when is_atom(msg), do: msg
  def name(msg) when is_tuple(msg), do: elem(msg, 0)
  def name(%{__struct__: module}), do: module

  @doc """
  Returns the message payload.

  For atoms, returns nil.
  For tuples with 2 elements, returns the second element.
  For tuples with more elements, returns a list of remaining elements.
  For structs, returns the struct itself.
  """
  @spec payload(t()) :: term()
  def payload(msg) when is_atom(msg), do: nil
  def payload(msg) when is_tuple(msg) and tuple_size(msg) == 1, do: nil
  def payload(msg) when is_tuple(msg) and tuple_size(msg) == 2, do: elem(msg, 1)
  def payload(msg) when is_tuple(msg), do: Tuple.to_list(msg) |> tl()
  def payload(%{__struct__: _} = msg), do: msg

  @doc """
  Creates a wrapped message result from event_to_msg.

  Returns `{:msg, message}` to indicate the event was converted.
  """
  @spec wrap(t()) :: {:msg, t()}
  def wrap(msg), do: {:msg, msg}

  @doc """
  Checks if a value is an atom message.
  """
  @spec atom?(term()) :: boolean()
  def atom?(msg) when is_atom(msg) and not is_nil(msg), do: true
  def atom?(_), do: false

  @doc """
  Checks if a value is a tuple message.
  """
  @spec tuple?(term()) :: boolean()
  def tuple?(msg) when is_tuple(msg) and tuple_size(msg) >= 1, do: true
  def tuple?(_), do: false

  @doc """
  Checks if a value is a struct message.
  """
  @spec struct?(term()) :: boolean()
  def struct?(%{__struct__: _}), do: true
  def struct?(_), do: false

  @doc """
  Matches a message against a pattern.

  ## Examples

      Message.match?(:submit, :submit)  # true
      Message.match?({:select, 3}, :select)  # true
      Message.match?(%Msg.SelectItem{index: 3}, Msg.SelectItem)  # true
  """
  @spec match?(t(), atom()) :: boolean()
  def match?(msg, pattern) when is_atom(msg), do: msg == pattern
  def match?(msg, pattern) when is_tuple(msg), do: elem(msg, 0) == pattern
  def match?(%{__struct__: module}, pattern), do: module == pattern
  def match?(_, _), do: false
end
