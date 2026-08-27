defmodule TermUI.Terminal.SignalHandler do
  @moduledoc false

  @behaviour :gen_event

  @impl true
  def init(terminal) when is_pid(terminal) do
    enable_resize_signal()
    {:ok, terminal}
  end

  def init({terminal, restore_request, resize_message}) when is_pid(terminal) do
    enable_resize_signal()
    {:ok, {terminal, restore_request, resize_message}}
  end

  @impl true
  def handle_event(:sigwinch, terminal) when is_pid(terminal) do
    send(terminal, :sigwinch)
    {:ok, terminal}
  end

  def handle_event(:sigwinch, {terminal, _restore_request, resize_message} = state) do
    if resize_message, do: send(terminal, resize_message)
    {:ok, state}
  end

  def handle_event(:sigterm, terminal) when is_pid(terminal) do
    restore_terminal(terminal)
    {:ok, terminal}
  end

  def handle_event(:sigterm, {terminal, restore_request, _resize_message} = state) do
    restore_terminal(terminal, restore_request)
    {:ok, state}
  end

  def handle_event(_signal, terminal), do: {:ok, terminal}

  @impl true
  def handle_call(_request, terminal), do: {:ok, :ok, terminal}

  @impl true
  def handle_info(_message, terminal), do: {:ok, terminal}

  @impl true
  def terminate(_reason, _terminal), do: :ok

  @impl true
  def code_change(_old_version, terminal, _extra), do: {:ok, terminal}

  defp restore_terminal(terminal, request \\ :restore) do
    GenServer.call(terminal, request, 2000)
  catch
    :exit, _reason -> :ok
  end

  # OTP 26 exposes os:set_signal/2 but rejects SIGWINCH. Keep the event
  # subscriber installed there so VM-handled signals such as SIGTERM remain
  # available; resize signals activate automatically on supporting versions.
  defp enable_resize_signal do
    :os.set_signal(:sigwinch, :handle)
  rescue
    ArgumentError -> :ok
  end
end
