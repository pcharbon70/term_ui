#!/bin/bash
# Run this AFTER mouse garbage appears to test if bash can fix tracking
printf '\e[?1006l\e[?1003l\e[?1002l\e[?1000l'
echo "Mouse-off sent via bash printf. Move mouse - is it clean now?"
