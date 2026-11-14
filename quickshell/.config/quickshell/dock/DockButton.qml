import QtQuick

// Same footprint and hover look as DockItem, but with a glyph instead of an app icon.
Item {
    id: root

    property string glyph: ""
    property string tip: ""
    property int iconSize: 40
    property bool active: false
    property bool tipEnabled: true
    signal clicked

    width: iconSize + 14
    height: iconSize + 20

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.iconSize + 12
        radius: 10
        color: (root.active || mouse.containsMouse) ? Theme.surface : "transparent"
        border.width: 1
        border.color: mouse.containsMouse ? Theme.border : "transparent"
    }

    Text {
        x: (parent.width - width) / 2
        y: 6 + (root.iconSize - height) / 2
        text: root.glyph
        color: (root.active || mouse.containsMouse) ? Theme.accent : Theme.muted
        font.family: Theme.font
        font.pixelSize: 22
        scale: mouse.pressed ? 0.9 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: mouse.containsMouse && root.tipEnabled && root.tip !== ""
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
            text: root.tip
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
