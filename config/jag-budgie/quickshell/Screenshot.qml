import QtQuick
import Quickshell

BarModule {
    icon: "󰻛"
    iconColor: Theme.magenta

    onClicked: Quickshell.execDetached([
        "sh", "-c",
        "mkdir -p \"$HOME/Pictures/Screenshots\"; g=$(slurp) || exit; grim -g \"$g\" \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
    ])
}
