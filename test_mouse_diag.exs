#!/usr/bin/env elixir
# Diagnostic: isolate ConPTY mouse tracking re-enable behavior
# Run:  elixir test_mouse_diag.exs <test_number>

defmodule MouseDiag do
  @mouse_on "\e[?1000h\e[?1002h\e[?1003h\e[?1006h"
  @mouse_off "\e[?1006l\e[?1003l\e[?1002l\e[?1000l"
  @alt_on "\e[?1049h"
  @alt_off "\e[?1049l"
  @cursor_show "\e[?25h"
  @sgr_reset "\e[0m"

  def usage do
    IO.puts("""
    Usage: elixir test_mouse_diag.exs <test_number>

    KEY TESTS — run these:
      20  Enable mouse, DON'T disable, exit (for wrapper test)
          Run as: bash test_wrapper.sh 20
      21  Enable mouse, disable in child, exit (for wrapper test)
          Run as: bash test_wrapper.sh 21
      22  Enable mouse in a PORT (child process), disable in BEAM, exit
      23  Enable+disable mouse in a PORT (child process), BEAM just waits
      24  Enable mouse via Port, exit, wrapper disables
          Run as: bash test_wrapper.sh 24

    Previous tests (all GARBAGE — confirms terminal-level issue):
      1   Current approach → GARBAGE
      10  SIGKILL → GARBAGE
      12  No mouse tracking → CLEAN (baseline)
    """)
  end

  def run(n) do
    IO.puts("--- Test #{n} starting in 1 second ---")
    Process.sleep(1000)
    apply(__MODULE__, :"test_#{n}", [])
  end

  # === WRAPPER TESTS (run with: bash test_wrapper.sh <N>) ===

  # Test 20: Enable mouse, DO NOT disable, just exit.
  # The wrapper script will send mouse-off AFTER we exit.
  # Theory: ConPTY re-enables tracking for the process that enabled it.
  # If the WRAPPER disables (not the process that enabled), it should stick.
  def test_20 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on <> @mouse_on)
    IO.write("\e[2J\e[HTest 20: Mouse ON, will NOT disable. Waiting 2s...")
    Process.sleep(2000)
    # Leave alt screen and show cursor, but DON'T send mouse-off
    IO.write(@cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Exiting WITHOUT mouse-off. Wrapper will handle it. ---")
    Process.sleep(200)
  end

  # Test 21: Enable mouse, disable in child, exit.
  # Wrapper ALSO sends mouse-off after exit.
  # Tests if double-disable (child + wrapper) works.
  def test_21 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on <> @mouse_on)
    IO.write("\e[2J\e[HTest 21: Full cleanup + wrapper. Waiting 2s...")
    Process.sleep(2000)
    IO.write(@mouse_off <> @cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Disabled in child. Wrapper will also disable. ---")
    Process.sleep(200)
  end

  # Test 22: Enable mouse via a PORT (child OS process), disable in BEAM.
  # If ConPTY tracks mouse-enable per process, the PORT process enabled it,
  # and when the PORT dies, ConPTY might re-enable. But BEAM disabled it,
  # and when BEAM dies, ConPTY shouldn't re-enable (BEAM never enabled).
  def test_22 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on)

    # Enable mouse via external printf (different OS process)
    port =
      Port.open(
        {:spawn, "printf '\\e[?1000h\\e[?1002h\\e[?1003h\\e[?1006h'"},
        [:nouse_stdio, :binary, :exit_status]
      )

    receive do
      {^port, {:exit_status, _}} -> :ok
    after
      1000 -> :ok
    end

    IO.write("\e[2J\e[HTest 22: Mouse enabled via Port. Waiting 2s...")
    Process.sleep(2000)

    # Disable mouse from BEAM (different process than the one that enabled)
    IO.write(@mouse_off <> @cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Mouse enabled by Port, disabled by BEAM. Move mouse 10s. ---")
    Process.sleep(10_000)
  end

  # Test 23: Enable AND disable mouse both in a PORT (same child process).
  # BEAM never touches mouse tracking at all.
  def test_23 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on)

    # Enable mouse via external printf
    port =
      Port.open(
        {:spawn, "printf '\\e[?1000h\\e[?1002h\\e[?1003h\\e[?1006h'"},
        [:nouse_stdio, :binary, :exit_status]
      )

    receive do
      {^port, {:exit_status, _}} -> :ok
    after
      1000 -> :ok
    end

    IO.write("\e[2J\e[HTest 23: Mouse enabled via Port. Waiting 2s...")
    Process.sleep(2000)

    # Disable mouse ALSO via external printf (same approach, new process)
    port2 =
      Port.open(
        {:spawn, "printf '\\e[?1000l\\e[?1002l\\e[?1003l\\e[?1006l'"},
        [:nouse_stdio, :binary, :exit_status]
      )

    receive do
      {^port2, {:exit_status, _}} -> :ok
    after
      1000 -> :ok
    end

    IO.write(@cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Mouse enabled+disabled both via Port. Move mouse 10s. ---")
    Process.sleep(10_000)
  end

  # Test 24: Enable mouse via Port, don't disable, let wrapper handle it.
  # Run with: bash test_wrapper.sh 24
  def test_24 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on)

    # Enable mouse via external printf
    port =
      Port.open(
        {:spawn, "printf '\\e[?1000h\\e[?1002h\\e[?1003h\\e[?1006h'"},
        [:nouse_stdio, :binary, :exit_status]
      )

    receive do
      {^port, {:exit_status, _}} -> :ok
    after
      1000 -> :ok
    end

    IO.write("\e[2J\e[HTest 24: Mouse via Port, no disable. Waiting 2s...")
    Process.sleep(2000)
    IO.write(@cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Exiting. Wrapper will send mouse-off. ---")
    Process.sleep(200)
  end

  # === PREVIOUS TESTS (for reference) ===

  def test_1 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on <> @mouse_on)
    IO.write("\e[2J\e[HTest 1: Full approach. Waiting 2s...")
    Process.sleep(2000)
    IO.write(@mouse_off <> @cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- Move mouse for 10 sec ---")
    Process.sleep(10_000)
  end

  def test_10 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on <> @mouse_on)
    IO.write("\e[2J\e[HTest 10: SIGKILL. Waiting 2s...")
    Process.sleep(2000)
    IO.write(@mouse_off <> @cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- SIGKILL in 2s ---")
    Process.sleep(2000)
    System.cmd("kill", ["-9", "#{:os.getpid()}"])
  end

  def test_12 do
    :shell.start_interactive({:noshell, :raw})
    IO.write(@alt_on)
    IO.write("\e[2J\e[HTest 12: No mouse. Waiting 2s...")
    Process.sleep(2000)
    IO.write(@cursor_show <> @sgr_reset <> @alt_off)
    :shell.start_interactive({:noshell, :cooked})
    IO.puts("\r\n--- No mouse enabled. Move mouse 5s. ---")
    Process.sleep(5000)
  end
end

case System.argv() do
  [n] when n in ~w(1 10 12 20 21 22 23 24) ->
    MouseDiag.run(n)

  _ ->
    MouseDiag.usage()
end
