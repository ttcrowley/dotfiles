import QtQuick

// Bar button for the notification history.
//   left click  -> open / close the history panel
//   right click -> toggle Do Not Disturb
// The glyph turns into a crossed-out bell while DND is on, and a small badge
// counts what arrived since you last opened the panel.
Item {
    id: bell

    implicitWidth: 22
    implicitHeight: 22

    readonly property bool hovered: area.containsMouse

    Text {
        anchors.centerIn: parent
        text: NotifState.dnd ? "\uf1f6" : "\uf0f3"   // bell-slash / bell (Nerd Font)
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 2
        color: (NotifState.historyOpen || bell.hovered) ? Theme.accent
             : NotifState.dnd ? Theme.dim
             : Theme.dim
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        visible: NotifState.unread > 0
        x: parent.width - width   // inside the box: the drawer clips anything outside
        y: 0
        width: Math.max(height, badge.implicitWidth + 6)
        height: 13
        radius: height / 2
        color: Theme.fg

        Text {
            id: badge
            anchors.centerIn: parent
            text: NotifState.unread > 9 ? "9+" : NotifState.unread
            color: Theme.bg
            font.family: Theme.font
            font.pixelSize: 9
            font.bold: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                NotifState.manualDnd = !NotifState.manualDnd;
            else
                NotifState.toggleHistory();
        }
    }
}
