import Quickshell
import QtQuick

Text {
    text: "\udb82\udcc7"
    color: Theme.accent
    font { family: Theme.font; pixelSize: Theme.fontSize + 6 }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        // Clicking again while rofi is open closes it
        onClicked: Quickshell.execDetached(["sh", "-c", "pkill rofi || rofi -show drun"])
    }
}
