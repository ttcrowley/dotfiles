#!/usr/bin/env bash
# rofi script mode: calculator on top of qalc (libqalculate)
# Type an expression and press Enter; pick the result line to copy it.

esc() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

echo -en "\0prompt\x1fcalc\n"

case "${ROFI_RETV:-0}" in
    1)  # selected the result line: copy and close
        printf '%s' "$1" | wl-copy
        exit 0
        ;;
    2)  # typed expression
        res=$(qalc -t -- "$1" 2>&1)
        echo -en "\0message\x1f$(esc "$1") = $(esc "$res")\n"
        echo "$res"
        ;;
    *)
        echo -en "\0message\x1fType an expression and press Enter\n"
        ;;
esac
