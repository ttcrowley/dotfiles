import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var item          // object from DockState.items
    property int iconSize: 40
    property bool tipEnabled: true
    signal menuRequested

    readonly property var windows: item.windows
    readonly property bool running: windows.length > 0
    readonly property bool active: windows.some(w => w.activated)

    width: iconSize + 14
    height: iconSize + 20

    function iconSource(name) {
        if (!name) return Quickshell.iconPath("application-x-executable");
        if (name.startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, "application-x-executable");
    }

    // hover / active background
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.iconSize + 12
        radius: 10
        color: (root.active || mouse.containsMouse) ? Theme.surface : "transparent"
        border.width: 1
        border.color: mouse.containsMouse ? Theme.border : "transparent"
    }

    IconImage {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        implicitSize: root.iconSize
        source: root.iconSource(root.item.icon)
        scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.12 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // running indicator (up to 3 pills, one per window)
    Row {
        visible: root.running
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.iconSize + 14
        spacing: 3

        Repeater {
            model: Math.min(root.windows.length, 3)
            Rectangle {
                width: (root.active && root.windows.length === 1) ? 14 : 5
                height: 3
                radius: 2
                color: root.active ? Theme.accent : Theme.muted
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }
    }

    // tooltip
    Rectangle {
        visible: mouse.containsMouse && root.tipEnabled
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - 12
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 12
        radius: 8
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.item.name + (root.windows.length > 1 ? "  ·  " + root.windows.length : "")
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: ev => {
            if (ev.button === Qt.RightButton)
                root.menuRequested();
            else if (ev.button === Qt.MiddleButton)
                DockState.closeWindow(root.item);
            else
                DockState.activate(root.item);
        }
    }
}
