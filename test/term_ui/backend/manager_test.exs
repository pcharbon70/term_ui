defmodule TermUI.Backend.ManagerTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.Manager
  alias TermUI.Test.DeterministicBackend

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

  defp start_manager(opts) do
    assert {:ok, manager} =
             Manager.start_link(
               self(),
               {DeterministicBackend, owner: self()},
               opts
             )

    assert_receive {:backend, :init, ^manager}
    manager
  end
end
