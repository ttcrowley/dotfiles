import Quickshell
import QtQuick

// Drawer button: opens the clipboard history menu (ClipboardMenu.qml)
Item {
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        text: "\uf0ea"
        color: area.containsMouse ? Theme.fg : Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "clipboard", "toggle"])
    }
}
