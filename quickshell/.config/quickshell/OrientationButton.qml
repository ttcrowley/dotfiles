import QtQuick

// Click to switch the bar between horizontal (top) and vertical (left).
Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        // Shows where a click will take you:
        // horizontal bar -> arrows-v (go vertical); vertical bar -> arrows-h (go horizontal)
        text: BarState.vertical ? "\uf07e" : "\uf07d"
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
        onClicked: BarState.toggle()
    }
}
