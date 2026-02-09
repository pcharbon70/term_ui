#!/bin/bash
# Pure bash mouse tracking test — no Elixir/BEAM involved
# If this shows garbage after exit, it's a terminal/ConPTY issue
echo "Enabling mouse tracking via bash..."
printf '\e[?1000h\e[?1002h\e[?1003h\e[?1006h'
echo "Mouse ON. Waiting 3s (you'll see garbage if you move mouse)..."
sleep 3
printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'
echo "Mouse OFF. Move mouse for 5s — should be clean..."
sleep 5
echo "Done. If you see garbage after this, it's a terminal issue."
