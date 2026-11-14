#!/bin/sh
# Screenshot flow for the dock: hyprshot -> Satty (annotate) -> clipboard.
# Satty is the only thing that copies, so cliphist (which watches the clipboard)
# stores exactly one entry per screenshot.
#
# usage: shot.sh window | region | output

case "$1" in
    window) args="-m window" ;;
    region) args="-m region" ;;
    output) args="-m output -m active" ;;   # the focused monitor, no extra click
    *) echo "usage: shot.sh window|region|output" >&2; exit 1 ;;
esac

# let the dock finish sliding out of view before anything is captured
sleep 0.35

tmp=$(mktemp --suffix=.png) || exit 1
trap 'rm -f "$tmp"' EXIT

# --raw prints the PNG to stdout and neither saves nor copies it
# shellcheck disable=SC2086
hyprshot $args --raw > "$tmp" 2>/dev/null

# empty file = selection cancelled (Esc)
[ -s "$tmp" ] || exit 0

satty --filename "$tmp" --copy-command wl-copy --early-exit
