defmodule TermUI.Backend.ManagerTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.Manager
  alias TermUI.{Clipboard, Event, Frame}
  alias TermUI.Test.DeterministicBackend

  defmodule NoClipboardBackend do
    @behaviour TermUI.Backend

    defdelegate init(opts), to: DeterministicBackend
    defdelegate size(state), to: DeterministicBackend
    defdelegate capabilities(state), to: DeterministicBackend
    defdelegate draw(state, frame), to: DeterministicBackend
    defdelegate flush(state), to: DeterministicBackend
    defdelegate poll_event(state, timeout), to: DeterministicBackend
    defdelegate resize(state, size), to: DeterministicBackend
    defdelegate shutdown(state, reason), to: DeterministicBackend
  end

  test "accepts a custom size poll interval" do
    manager = start_manager(size_poll_interval: 75)

    assert %{size_poll_interval: 75} = :sys.get_state(manager)
    assert :ok = Manager.close(manager, :normal)
  end

  test "can disable size polling" do
    manager = start_manager(size_poll_interval: :disabled)

    assert %{size_poll_interval: nil} = :sys.get_state(manager)
    assert :ok = Manager.close(manager, :normal)
  end

  test "rejects an unsafe size poll interval" do
    previous = Process.flag(:trap_exit, true)

    try do
      assert {:error, {:invalid_size_poll_interval, 20}} =
               Manager.start_link(
                 self(),
                 {DeterministicBackend, owner: self()},
                 size_poll_interval: 20
               )

      refute_receive {:backend, :init, _pid}
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "serializes frame, clipboard, resize, and cleanup callbacks" do
    manager = start_manager(size_poll_interval: :disabled)
    frame = Frame.from_rows(["ok"], 20, 6)
    operation = Clipboard.operation("copy")

    assert %{backend: DeterministicBackend, size: {6, 20}, capabilities: capabilities} =
             Manager.info(manager)

    assert capabilities.colors == :true_color
    assert :ok = Manager.draw(manager, frame)
    assert_receive {:backend, :draw, ^frame}
    assert :ok = Manager.flush(manager)
    assert_receive {:backend, :flush, 1}
    assert :ok = Manager.clipboard(manager, operation)
    assert_receive {:backend, :clipboard, ^operation}
    assert :ok = Manager.resize(manager, {12, 40})
    assert_receive {:backend, :resize, {12, 40}}
    assert %{size: {12, 40}} = Manager.info(manager)
    assert :ok = Manager.close(manager, :complete)
    assert_receive {:backend, :shutdown, :complete}
  end

  test "delivers input and stops polling after an input failure" do
    event = Event.text("x")
    manager = start_manager([], events: [event])

    assert :ok = Manager.activate(manager)
    assert_receive {:backend_event, ^event}, 100
    assert :ok = Manager.close(manager, :normal)

    manager = start_manager([], fail: :input)
    assert :ok = Manager.activate(manager)

    assert_receive {:backend_failed, {:backend, DeterministicBackend, :input, :input_failed}},
                   100

    assert :ok = Manager.close(manager, :normal)
  end

  test "returns structured callback failures" do
    manager = start_manager([], fail: :clipboard)

    assert {:error, {:backend, DeterministicBackend, :clipboard, :clipboard_failed}} =
             Manager.clipboard(manager, Clipboard.operation("copy"))

    assert :ok = Manager.close(manager, :normal)

    manager = start_manager([], fail: :resize)

    assert {:error, {:backend, DeterministicBackend, :resize, :resize_failed}} =
             Manager.resize(manager, {10, 30})

    assert :ok = Manager.close(manager, :normal)
  end

  test "reports an optional clipboard callback as unsupported" do
    assert {:ok, manager} =
             Manager.start_link(
               self(),
               {NoClipboardBackend, owner: self()},
               size_poll_interval: :disabled
             )

    assert_receive {:backend, :init, ^manager}

    assert {:error, {:backend, NoClipboardBackend, :clipboard, :unsupported}} =
             Manager.clipboard(manager, Clipboard.operation("copy"))

    assert :ok = Manager.close(manager, :normal)
  end

  test "cleans an opened backend when later setup fails" do
    previous = Process.flag(:trap_exit, true)

    try do
      reason = {:backend, DeterministicBackend, :size, :size_failed}

      assert {:error, ^reason} =
               Manager.start_link(
                 self(),
                 {DeterministicBackend, owner: self(), fail: :size},
                 size_poll_interval: :disabled
               )

      assert_receive {:backend, :init, _manager}
      assert_receive {:backend, :shutdown, ^reason}
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "cleans the backend when its owner is killed" do
    test_process = self()

    owner =
      spawn(fn ->
        {:ok, manager} =
          Manager.start_link(
            self(),
            {DeterministicBackend, owner: test_process},
            size_poll_interval: :disabled
          )

        send(test_process, {:manager, manager})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:backend, :init, manager}
    assert_receive {:manager, ^manager}
    reference = Process.monitor(manager)

    Process.exit(owner, :kill)

    assert_receive {:backend, :shutdown, :killed}
    assert_receive {:DOWN, ^reference, :process, ^manager, :killed}, 500
  end

  defp start_manager(opts, backend_opts \\ []) do
    assert {:ok, manager} =
             Manager.start_link(
               self(),
               {DeterministicBackend, [owner: self()] ++ backend_opts},
               opts
             )

    assert_receive {:backend, :init, ^manager}
    manager
  end
end
