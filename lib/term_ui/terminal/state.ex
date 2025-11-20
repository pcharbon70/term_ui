defmodule TermUI.Terminal.State do
  @moduledoc """
  Terminal state structure tracking raw mode status, original settings,
  and active features (mouse tracking, bracketed paste, alternate screen).
  """

  @type t :: %__MODULE__{
          raw_mode_active: boolean(),
          alternate_screen_active: boolean(),
          cursor_visible: boolean(),
          mouse_tracking: :off | :x10 | :normal | :button | :all,
          bracketed_paste: boolean(),
          focus_events: boolean(),
          original_settings: term() | nil,
          size: {rows :: pos_integer(), cols :: pos_integer()} | nil,
          resize_callbacks: [pid()]
        }

  defstruct raw_mode_active: false,
            alternate_screen_active: false,
            cursor_visible: true,
            mouse_tracking: :off,
            bracketed_paste: false,
            focus_events: false,
            original_settings: nil,
            size: nil,
            resize_callbacks: []

  @doc """
  Creates a new terminal state with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new terminal state with the given size.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(rows, cols) when is_integer(rows) and is_integer(cols) and rows > 0 and cols > 0 do
    %__MODULE__{size: {rows, cols}}
  end
end
