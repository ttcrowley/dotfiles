import QtQuick

// Same footprint and hover look as DockItem, but with a glyph instead of an app icon.
Item {
    id: root

    property string glyph: ""
    property string tip: ""
    property int iconSize: 40
    property bool active: false
    property bool tipEnabled: true

    // ── Entrance animation ──
    // Flip `revealed` to true and the button pops/slides in after `revealDelay` ms.
    // Leaving (`revealed` → false) hides it immediately, no delay — so exit stays snappy.
    property bool revealed: true
    property int revealDelay: 0

    // Drives the visual: 0 = hidden, 1 = fully in. Behavior adds the pop.
    property real presence: 0
    Behavior on presence {
        NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }

    onRevealedChanged: {
        if (revealed) {
            showTimer.restart();
        } else {
            showTimer.stop();
            presence = 0;
        }
    }
    Component.onCompleted: presence = revealed ? 1 : 0

    Timer {
        id: showTimer
        interval: root.revealDelay
        onTriggered: root.presence = root.revealed ? 1 : 0
    }

    signal clicked

    width: iconSize + 14
    height: iconSize + 20

    // ── Visual content (scales/slides in as one unit) ──
    Item {
        id: content
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.iconSize + 12
        opacity: root.presence
        scale: 0.7 + 0.3 * root.presence
        y: (1 - root.presence) * 6
        transformOrigin: Item.Bottom

        // Hover / active background — now fades instead of snapping
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: (root.active || mouse.containsMouse) ? Theme.surface : "transparent"
            border.width: 1
            border.color: mouse.containsMouse ? Theme.border : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }
        }

        // Glyph — fades, grows on hover, squishes on press
        Text {
            x: (parent.width - width) / 2
            y: 6 + (root.iconSize - height) / 2
            text: root.glyph
            color: (root.active || mouse.containsMouse) ? Theme.accent : Theme.muted
            Behavior on color { ColorAnimation { duration: 160 } }
            font.family: Theme.font
            font.pixelSize: 22
            scale: mouse.pressed ? 0.88 : (mouse.containsMouse ? 1.12 : 1.0)
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    // ── Tooltip (outside `content`, so it doesn't scale with the entrance) ──
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
