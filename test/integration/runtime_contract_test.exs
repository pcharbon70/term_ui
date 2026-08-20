defmodule TermUI.RuntimeContractTest do
  use ExUnit.Case, async: false

  alias TermUI.{Command, Event, Frame, Runtime}
  alias TermUI.Test.DeterministicBackend

  setup do
    previous = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, previous) end)
    :ok
  end

  defmodule Counter do
    use TermUI.Elm

    def init(opts), do: %{count: 0, owner: Keyword.fetch!(opts, :owner)}

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Text{text: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(_event, _state), do: :ignore

    def update(:increment, state), do: {%{state | count: state.count + 1}, []}
    def update(:quit, state), do: {%{state | count: state.count + 1}, [Command.shutdown()]}
    def update({:set, count}, state), do: {%{state | count: count}, []}

    def view(state), do: Frame.from_rows(["count=#{state.count}"], 20, 2, cursor: {1, 2})

    def terminate(reason, state) do
      send(state.owner, {:app_terminated, reason, state.count})
      :ok
    end
  end

  defmodule CrashingApp do
    use TermUI.Elm

    def init(opts), do: %{owner: Keyword.fetch!(opts, :owner)}
    def event_to_msg(_event, _state), do: {:msg, :crash}
    def update(:crash, _state), do: raise("application failed")
    def view(_state), do: Frame.from_rows(["ready"], 20, 2)
  end

  defmodule InitCrashingApp do
    use TermUI.Elm

    def init(_opts), do: raise("init failed")
    def event_to_msg(_event, _state), do: :ignore
    def update(_message, state), do: state
    def view(_state), do: Frame.from_rows(["unused"], 10, 1)
  end

  defmodule InfoApp do
    use TermUI.Elm

    def init(opts), do: %{owner: Keyword.fetch!(opts, :owner), info: nil}
    def event_to_msg(_event, _state), do: :ignore
    def update(_message, state), do: state

    def handle_info(message, state) do
      {%{state | info: message}, [Command.send(state.owner, {:application_info, message})]}
    end

    def view(state), do: Frame.from_rows([inspect(state.info)], 40, 2)
  end

  defmodule AsyncApp do
    use TermUI.Elm

    def init(opts) do
      state = %{owner: Keyword.fetch!(opts, :owner)}
      command = Command.async(Keyword.fetch!(opts, :async_function), &{:async_complete, &1})
      {state, [command]}
    end

    def event_to_msg(_event, _state), do: :ignore

    def update({:async_complete, result}, state) do
      {state, [Command.send(state.owner, {:async_complete, result})]}
    end

    def view(_state), do: Frame.from_rows(["async"], 20, 2)
  end

  defmodule ResizableApp do
    use TermUI.Elm

    def init(opts), do: %{dimensions: Keyword.fetch!(opts, :dimensions)}

    def event_to_msg(%Event.Resize{width: width, height: height}, _state),
      do: {:msg, {:resize, width, height}}

    def event_to_msg(%Event.Text{text: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(_event, _state), do: :ignore
    def update({:resize, width, height}, state), do: %{state | dimensions: {width, height}}
    def update(:quit, state), do: {state, [Command.shutdown()]}

    def view(%{dimensions: {width, height}}),
      do: Frame.from_rows(["#{width}x#{height}"], width, height)
  end

  test "an injected backend receives normalized input and the final meaningful frame" do
    events = [Event.key(:up), Event.text("q")]

    assert {:ok, runtime} =
             Runtime.start_link(
               root: Counter,
               owner: self(),
               backend: {DeterministicBackend, owner: self(), events: events},
               render_interval: 50
             )

    runtime_ref = Process.monitor(runtime)

    assert_receive {:backend, :draw, first}, 500
    assert Frame.row_text(first, 1) == "count=0             "

    assert_receive {:backend, :draw, final}, 500
    assert Frame.row_text(final, 1) == "count=2             "
    assert final.cursor == {1, 2}
    assert_receive {:backend, :shutdown, :normal}, 500
    assert_receive {:backend, :shutdown_state, 0, 2}, 500
    assert_receive {:app_terminated, :normal, 2}, 500
    assert_receive {:DOWN, ^runtime_ref, :process, ^runtime, :normal}, 500
  end

  test "many updates coalesce into bounded output and external shutdown draws the newest state" do
    {:ok, runtime} = start_counter(render_interval: 100)
    assert_receive {:backend, :draw, _initial}, 500

    Enum.each(1..200, &Runtime.send_message(runtime, {:set, &1}))
    Runtime.shutdown(runtime)

    assert_receive {:backend, :draw, final}, 500
    assert Frame.row_text(final, 1) == "count=200           "
    assert_receive {:backend, :shutdown, :normal}, 500
    refute_receive {:backend, :draw, _extra}, 150
  end

  test "draw and flush failures are useful and still clean the backend" do
    for {stage, reason} <- [draw: :draw_failed, flush: :flush_failed] do
      assert {:error, {:backend, DeterministicBackend, ^stage, ^reason}} =
               Runtime.run(
                 root: Counter,
                 owner: self(),
                 backend: {DeterministicBackend, owner: self(), fail: stage}
               )

      assert_receive {:backend, :shutdown, {:backend, DeterministicBackend, ^stage, ^reason}}, 500
    end
  end

  test "size, capability, and application init failures clean an opened backend" do
    assert {:error, {:backend, DeterministicBackend, :size, :size_failed} = size_reason} =
             Runtime.run(
               root: Counter,
               owner: self(),
               backend: {DeterministicBackend, owner: self(), fail: :size}
             )

    assert_receive {:backend, :shutdown, ^size_reason}, 500

    assert {:error,
            {:backend, DeterministicBackend, :capabilities,
             %RuntimeError{message: "capabilities failed"}} = capabilities_reason} =
             Runtime.run(
               root: Counter,
               owner: self(),
               backend: {DeterministicBackend, owner: self(), fail: :capabilities}
             )

    assert_receive {:backend, :shutdown, ^capabilities_reason}, 500

    assert {:error,
            {:application, :init, {:error, %RuntimeError{message: "init failed"}, _stacktrace}} =
              init_reason} =
             Runtime.run(
               root: InitCrashingApp,
               owner: self(),
               backend: {DeterministicBackend, owner: self()}
             )

    assert_receive {:backend, :shutdown, ^init_reason}, 500
  end

  test "an application failure still cleans the backend" do
    assert {:ok, runtime} =
             Runtime.start_link(
               root: CrashingApp,
               owner: self(),
               backend: {DeterministicBackend, owner: self(), events: [Event.key(:enter)]}
             )

    ref = Process.monitor(runtime)
    assert_receive {:backend, :draw, _frame}, 500

    assert_receive {:DOWN, ^ref, :process, ^runtime, {:application, :update, _failure}}, 500
    assert_receive {:backend, :shutdown, {:application, :update, _failure}}, 500
  end

  test "unknown monitor messages reach the application" do
    assert {:ok, runtime} =
             Runtime.start_link(
               root: InfoApp,
               owner: self(),
               backend: {DeterministicBackend, owner: self()}
             )

    assert_receive {:backend, :draw, _frame}, 500
    down = {:DOWN, make_ref(), :process, self(), :test_reason}
    send(runtime, down)
    assert_receive {:application_info, ^down}, 500
    Runtime.shutdown(runtime)
  end

  test "resize updates the backend and the final frame dimensions" do
    events = [Event.resize(7, 3), Event.text("q")]

    assert {:ok, _runtime} =
             Runtime.start_link(
               root: ResizableApp,
               backend: {DeterministicBackend, owner: self(), events: events}
             )

    assert_receive {:backend, :draw, %Frame{width: 20, height: 6}}, 500
    assert_receive {:backend, :draw, %Frame{width: 7, height: 3} = final}, 500
    assert Frame.row_text(final, 1) == "7x3    "
    assert_receive {:backend, :shutdown, :normal}, 500
  end

  test "async commands tag a bare return value as successful" do
    runtime = start_async_app(fn -> :completed end)

    assert_receive {:async_complete, {:ok, :completed}}, 500
    Runtime.shutdown(runtime)
  end

  test "async commands preserve a tagged return value inside the success result" do
    runtime = start_async_app(fn -> {:ok, :inner} end)

    assert_receive {:async_complete, {:ok, {:ok, :inner}}}, 500
    Runtime.shutdown(runtime)
  end

  test "async commands tag raised failures as errors" do
    runtime = start_async_app(fn -> raise "async failed" end)

    assert_receive {:async_complete,
                    {:error, {:error, %RuntimeError{message: "async failed"}, _stacktrace}}},
                   500

    Runtime.shutdown(runtime)
  end

  defp start_counter(opts) do
    Runtime.start_link(
      [
        root: Counter,
        owner: self(),
        backend: {DeterministicBackend, owner: self()}
      ] ++ opts
    )
  end

  defp start_async_app(async_function) do
    assert {:ok, runtime} =
             Runtime.start_link(
               root: AsyncApp,
               owner: self(),
               async_function: async_function,
               backend: {DeterministicBackend, owner: self()}
             )

    assert_receive {:backend, :draw, _frame}, 500
    runtime
  end
end
