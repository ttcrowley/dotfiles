import QtQuick

// Cancel / Save style button for the task editor.
Rectangle {
    id: btn

    property string label
    property bool primary: false
    signal clicked()

    width: 84
    height: 34
    radius: 8
    color: primary ? Theme.accent : "transparent"
    border { color: primary ? Theme.accent : Theme.border; width: 1 }
    opacity: area.containsMouse ? 0.85 : 1

    Text {
        anchors.centerIn: parent
        text: btn.label
        color: btn.primary ? Theme.bg : Theme.fg
        font { family: Theme.font; pixelSize: Theme.fontSize - 2; bold: btn.primary }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
