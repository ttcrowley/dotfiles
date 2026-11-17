import Quickshell
import QtQuick

Text {
    id: root
    text: "\udb82\udcc7"
    color: Theme.accent
    font { family: Theme.font; pixelSize: Theme.fontSize + 6 }

    // Slightly softened at rest, full brightness on hover
    opacity: area.containsMouse ? 1 : 0.8
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Opens the dock's launcher state; clicking again closes it
        onClicked: Quickshell.execDetached([
            "qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/dock",
            "ipc", "call", "dock", "launcher"
        ])
    }
}
