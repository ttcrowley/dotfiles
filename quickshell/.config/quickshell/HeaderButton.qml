import QtQuick

// Small outlined button used in the notification history header.
Rectangle {
    id: hb

    property string label
    property bool active: false
    property int cornerRadius: Theme.radiusSmall
    signal clicked

    implicitWidth: hbText.implicitWidth + 16
    implicitHeight: hbText.implicitHeight + 8
    radius: hb.cornerRadius
    color: hbArea.containsMouse ? Theme.surface : "transparent"
    border.width: 1
    border.color: hb.active ? Theme.fg : (hbArea.containsMouse ? Theme.dim : Theme.border)

    Text {
        id: hbText
        anchors.centerIn: parent
        text: hb.label
        color: hb.active ? Theme.fg : Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
    }

    MouseArea {
        id: hbArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hb.clicked()
    }
}
