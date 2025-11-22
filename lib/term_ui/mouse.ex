defmodule TermUI.Mouse do
  @moduledoc """
  Mouse support utilities for terminal applications.

  Provides functions to enable/disable mouse tracking modes and
  utilities for working with mouse events.

  ## Mouse Tracking Modes

  - **Normal (1000)** - Report button press/release
  - **Button (1002)** - Report motion while button pressed
  - **Any (1003)** - Report all motion events
  - **SGR Extended (1006)** - Decimal coordinates, press/release distinction

  ## Usage

      # Enable mouse tracking
      sequences = Mouse.enable_mouse()
      IO.write(sequences)

      # Enable motion tracking with SGR Extended
      sequences = Mouse.enable_mouse_motion()
      IO.write(sequences)

      # Disable mouse tracking
      sequences = Mouse.disable_mouse()
      IO.write(sequences)
  """

  # Mouse tracking mode escape sequences
  @mouse_normal_on "\e[?1000h"
  @mouse_normal_off "\e[?1000l"
  @mouse_button_on "\e[?1002h"
  @mouse_button_off "\e[?1002l"
  @mouse_any_on "\e[?1003h"
  @mouse_any_off "\e[?1003l"
  @mouse_sgr_on "\e[?1006h"
  @mouse_sgr_off "\e[?1006l"

  @doc """
  Returns escape sequences to enable normal mouse tracking.

  Normal mode reports button press and release events.
  Also enables SGR Extended mode for accurate coordinates.
  """
  @spec enable_mouse() :: String.t()
  def enable_mouse do
    @mouse_normal_on <> @mouse_sgr_on
  end

  @doc """
  Returns escape sequences to enable button motion tracking.

  Button mode reports motion events while a button is pressed.
  Also enables SGR Extended mode for accurate coordinates.
  """
  @spec enable_mouse_button() :: String.t()
  def enable_mouse_button do
    @mouse_button_on <> @mouse_sgr_on
  end

  @doc """
  Returns escape sequences to enable all motion tracking.

  Any mode reports all mouse motion events.
  Also enables SGR Extended mode for accurate coordinates.
  """
  @spec enable_mouse_motion() :: String.t()
  def enable_mouse_motion do
    @mouse_any_on <> @mouse_sgr_on
  end

  @doc """
  Returns escape sequences to disable all mouse tracking.
  """
  @spec disable_mouse() :: String.t()
  def disable_mouse do
    @mouse_sgr_off <> @mouse_any_off <> @mouse_button_off <> @mouse_normal_off
  end

  @doc """
  Returns the escape sequence for SGR Extended mode.

  SGR Extended mode provides:
  - Decimal coordinate encoding (no 223 limit)
  - Press/release distinction via 'm' vs 'M' suffix
  """
  @spec sgr_extended_on() :: String.t()
  def sgr_extended_on, do: @mouse_sgr_on

  @doc """
  Returns the escape sequence to disable SGR Extended mode.
  """
  @spec sgr_extended_off() :: String.t()
  def sgr_extended_off, do: @mouse_sgr_off

  # Scroll wheel directions
  @doc """
  Scroll up direction constant.
  """
  def scroll_up, do: :scroll_up

  @doc """
  Scroll down direction constant.
  """
  def scroll_down, do: :scroll_down

  @doc """
  Default number of lines to scroll per wheel tick.
  """
  def default_scroll_lines, do: 3

  @doc """
  Checks if a mouse action is a scroll action.
  """
  @spec scroll_action?(atom()) :: boolean()
  def scroll_action?(:scroll_up), do: true
  def scroll_action?(:scroll_down), do: true
  def scroll_action?(_), do: false

  @doc """
  Checks if a mouse action is a click action.
  """
  @spec click_action?(atom()) :: boolean()
  def click_action?(:press), do: true
  def click_action?(:release), do: true
  def click_action?(:click), do: true
  def click_action?(_), do: false

  @doc """
  Checks if a mouse action is a motion action.
  """
  @spec motion_action?(atom()) :: boolean()
  def motion_action?(:move), do: true
  def motion_action?(:drag), do: true
  def motion_action?(_), do: false
end
