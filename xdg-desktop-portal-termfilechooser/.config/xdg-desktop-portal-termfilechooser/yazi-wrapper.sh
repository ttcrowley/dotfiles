#!/bin/sh
# args from termfilechooser: multiple directory save path out
multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"

if [ "$directory" = "1" ]; then
    kitty --title termfilechooser yazi --cwd-file="$out"
else
    kitty --title termfilechooser yazi --chooser-file="$out" "${path:-$HOME}"
fi
