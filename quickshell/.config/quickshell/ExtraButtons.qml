import QtQuick

// A single chevron button on the bar. Click it and the
// notification bell and config (gear) buttons slide out in-line (to the left on a horizontal bar,
// upward on a vertical one). Click again to tuck them away, or just move the
// mouse off it: it hides itself after `hideDelay` ms.
Item {
    id: root

    property bool expanded: false
    readonly property bool vertical: BarState.vertical
    readonly property int gap: vertical ? 14 : 16

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Tuck the button away after flipping the orientation
    Connections {
        target: BarState
        function onVerticalChanged() { root.expanded = false }
    }

    // Auto-hide: collapse once the mouse has stayed off the drawer and the
    // chevron for this long (ms). Moving back over it cancels the countdown.
    property int hideDelay: 3000

    // Stay open while one of the drawer's popups is showing, since the mouse
    // is expected to be elsewhere then.
    readonly property bool busy: configMenu.open || NotifState.historyOpen

    HoverHandler { id: hover }

    Timer {
        interval: root.hideDelay
        running: root.expanded && !hover.hovered && !root.busy
        onTriggered: root.expanded = false
    }

    Grid {
        id: row
        columns: root.vertical ? 1 : 2
        spacing: 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // ── Revealed buttons ──
        Item {
            id: drawer
            clip: true
            visible: root.expanded || opacity > 0
            opacity: root.expanded ? 1 : 0

            // Content size plus the gap before the toggle, collapsing to 0
            // along the bar's main axis
            implicitWidth: root.vertical
                ? content.implicitWidth
                : (root.expanded ? content.implicitWidth + root.gap : 0)
            implicitHeight: root.vertical
                ? (root.expanded ? content.implicitHeight + root.gap : 0)
                : content.implicitHeight

            Behavior on implicitWidth  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity        { NumberAnimation { duration: 150 } }

            Grid {
                id: content
                columns: root.vertical ? 1 : 2
                spacing: root.gap
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                NotificationBell {}
                ConfigMenu { id: configMenu }
            }
        }

        // ── Toggle ──
        Item {
            implicitWidth: chevron.implicitWidth
            implicitHeight: chevron.implicitHeight

            Text {
                id: chevron
                // Points where the buttons will appear; flips when open
                text: root.vertical
                    ? (root.expanded ? "\uf107" : "\uf106")
                    : (root.expanded ? "\uf105" : "\uf104")
                color: area.containsMouse || root.expanded ? Theme.fg : Theme.dim
                font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Unread notifications while the drawer is tucked away
            Rectangle {
                visible: !root.expanded && NotifState.unread > 0
                width: 6
                height: 6
                radius: 3
                color: Theme.fg
                anchors {
                    right: parent.right
                    rightMargin: -3
                    top: parent.top
                    topMargin: -1
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
