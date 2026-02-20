defmodule TermUI.Integration.SSHRuntimeRenderingTest do
  use ExUnit.Case, async: false

  alias TermUI.Runtime

  defmodule RowToggleRoot do
    use TermUI.Elm

    @impl true
    def init(_opts), do: %{mode: :long}

    @impl true
    def event_to_msg(_event, _state), do: :ignore

    @impl true
    def update(:short, state), do: {%{state | mode: :short}, []}
    def update(:long, state), do: {%{state | mode: :long}, []}
    def update(_msg, state), do: {state, []}

    @impl true
    def view(%{mode: :long}) do
      [
        {:text, "ABCDEFGHIJ"},
        {:text, "1234567890"}
      ]
    end

    def view(%{mode: :short}) do
      [
        {:text, "AB"},
        {:text, "12"}
      ]
    end
  end

  defmodule FullFrame2x2Root do
    use TermUI.Elm

    @impl true
    def init(_opts), do: %{}

    @impl true
    def event_to_msg(_event, _state), do: :ignore

    @impl true
    def update(_msg, state), do: {state, []}

    @impl true
    def view(_state) do
      [
        {:text, "AB"},
        {:text, "CD"}
      ]
    end
  end

  defp start_ssh_runtime(root, device, opts \\ []) do
    size = Keyword.get(opts, :size, {4, 10})

    {:ok, runtime} =
      Runtime.start_link(
        [
          root: root,
          backend: {TermUI.Backend.SSH, device: device, size: size},
          render_interval: 60_000
        ] ++
          Keyword.drop(opts, [:size])
      )

    on_exit(fn ->
      if Process.alive?(runtime), do: Runtime.shutdown(runtime)
    end)

    runtime
  end

  defp force_render_sync(runtime) do
    Runtime.force_render(runtime)
    _ = :sys.get_state(runtime)
    :ok
  end

  defp output_snapshot(device) do
    {_input, output} = StringIO.contents(device)
    output
  end

  defp output_since(device, snapshot) do
    current = output_snapshot(device)

    if String.starts_with?(current, snapshot) do
      String.replace_prefix(current, snapshot, "")
    else
      current
    end
  end

  describe "custom SSH runtime diff rendering" do
    test "redraws changed rows without full-screen clear on shrink updates" do
      {:ok, device} = StringIO.open("")
      runtime = start_ssh_runtime(RowToggleRoot, device)

      force_render_sync(runtime)
      snapshot = output_snapshot(device)

      Runtime.send_message(runtime, :root, :short)
      :ok = Runtime.sync(runtime)
      force_render_sync(runtime)

      output = output_since(device, snapshot)

      assert output =~ "\e[1;1H\e[2K"
      assert output =~ "\e[2;1H\e[2K"
      assert output =~ "AB"
      assert output =~ "12"
      refute output =~ "\e[2J"
      refute output =~ "CDEFG"
    end

    test "does not emit bottom-right character for 2x2 full-frame content" do
      {:ok, device} = StringIO.open("")
      runtime = start_ssh_runtime(FullFrame2x2Root, device, size: {2, 2})

      force_render_sync(runtime)
      output = output_snapshot(device)

      assert output =~ "A"
      assert output =~ "B"
      assert output =~ "C"
      refute output =~ "D"
    end
  end
end
