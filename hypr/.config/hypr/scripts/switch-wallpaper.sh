#!/bin/bash
WALL="$1"
case "$WALL" in
    dark)  hyprctl hyprpaper wallpaper ",/home/crowley/Documentos/Wallpapers/saturn.jpg" ;;
    light) hyprctl hyprpaper wallpaper ",/home/crowley/Documentos/Wallpapers/wallhaven-skull.jpg" ;;
esac
