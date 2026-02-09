#!/bin/bash
# Wrapper that runs the Elixir test and sends mouse-off AFTER it exits.
# Usage: bash test_wrapper.sh <test_number>
#
# Theory: ConPTY re-enables mouse tracking when the process that
# ENABLED it exits. By having the WRAPPER (parent shell) send
# mouse-off, the disable comes from a different process context.

if [ -z "$1" ]; then
    echo "Usage: bash test_wrapper.sh <test_number>"
    echo "  20  Enable mouse, don't disable, wrapper handles cleanup"
    echo "  21  Enable+disable in child, wrapper also disables (belt+suspenders)"
    echo "  24  Enable via Port, don't disable, wrapper handles cleanup"
    exit 1
fi

echo "=== Wrapper: running elixir test $1 ==="
elixir test_mouse_diag.exs "$1"
EXIT_CODE=$?

echo "=== Wrapper: elixir exited ($EXIT_CODE). Sending mouse-off NOW ==="
printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'

echo "=== Wrapper: mouse-off sent. Move mouse for 10s ==="
sleep 10
echo "=== Wrapper: done ==="
