#!/usr/bin/env bash
# rofi script mode: screenshot popup (hyprshot -> Satty annotation)
#   rofi -show shot -modi "shot:~/.config/rofi/scripts/shot.sh" -theme ~/.config/rofi/shot.rasi

SAVE_DIR="$HOME/Imagens/Screenshots"

args_for() {
    case "$1" in
        window) echo "-m window" ;;
        region) echo "-m region" ;;
        *)      echo "-m output -m active" ;;   # whole active monitor, no extra click
    esac
}

run_shot() {
    local args
    args=$(args_for "$1")
    mkdir -p "$SAVE_DIR"
    ARGS="$args" SAVE_DIR="$SAVE_DIR" setsid -f bash -c '
        set -x
        sleep 0.35
        tmp=$(mktemp --suffix=.png)
        hyprshot $ARGS --raw > "$tmp"
	[ -s "$tmp" ] || { rm -f "$tmp"; exit 1; }
        satty --filename "$tmp" --early-exit --copy-command wl-copy \
              --output-filename "$SAVE_DIR/satty-$(date +%Y%m%d-%H%M%S).png"
        rm -f "$tmp"
    ' >/tmp/shot.log 2>&1
}

case "$ROFI_INFO" in
    window|region|output)
        run_shot "$ROFI_INFO"
        exit 0
        ;;
esac

echo -en "\0prompt\x1fshot\n"
echo -en "\0no-custom\x1ftrue\n"
echo -en "\0markup-rows\x1ftrue\n"
printf '%s\0info\x1f%s\n' '<span size="x-large"></span>  Window'   window
printf '%s\0info\x1f%s\n' '<span size="x-large"></span>  Area'    region
printf '%s\0info\x1f%s\n' '<span size="x-large"></span>  Screen' output
