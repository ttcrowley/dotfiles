import Quickshell
import Quickshell.Widgets
import QtQuick

// One app in the dock. The visuals live in `tile`, which is scaled (bottom-anchored)
// for hover / press / drag, so this item's own geometry never changes and the
// parent can lay it out and drag it freely.
Item {
    id: root

    property var item: ({ id: "", name: "", icon: "", windows: [], pinned: false })
    property int iconSize: 40
    property bool tipEnabled: true

    property bool draggable: false      // pinned apps can be reordered
    property bool lifted: false         // set by the parent while this item is being dragged
    property real zoom: 1.0             // hover magnification, set by the parent
    property bool present: true         // false = shrink and fade out (the app is leaving)
    property real hitPad: 0             // extra hover width on each side (closes the gaps between items)
    property int hitTop: 16             // extra hover height above (covers the magnified icon)

    signal menuRequested
    signal dragStarted
    signal dragMoved(real wantedX)      // where this item wants to be, in the parent's coordinates
    signal dragEnded
    signal hoverMoved(real cursorX)     // cursor x in the parent's coordinates
    signal hoverLeft

    readonly property var windows: item.windows
    readonly property bool running: windows.length > 0
    readonly property bool active: windows.some(w => w.activated)
    readonly property bool hovered: mouse.containsMouse

    width: iconSize + 14
    height: iconSize + 20
    z: lifted ? 10 : (hovered ? 5 : 0)

    // 0 -> 1 when the item appears, back to 0 when it leaves
    property real presence: 0
    onPresentChanged: presence = present ? 1 : 0
    Component.onCompleted: presence = present ? 1 : 0
    Behavior on presence { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function iconSource(name) {
        if (!name) return Quickshell.iconPath("application-x-executable");
        if (name.startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, "application-x-executable");
    }

    // ---------- tile: background + icon, scaled as one ----------
    Item {
        id: tile
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.iconSize + 12
        opacity: root.presence
        transformOrigin: Item.Bottom
        scale: root.zoom
             * (root.lifted ? 1.08 : 1.0)
             * ((mouse.pressed && !root.lifted) ? 0.94 : 1.0)
             * (0.7 + 0.3 * root.presence)

        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // hover / active background (fades instead of switching)
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.surface
            opacity: (root.active || root.hovered || root.lifted) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            opacity: (root.hovered || root.lifted) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            implicitSize: root.iconSize
            source: root.iconSource(root.item.icon)
        }
    }

    // ---------- running indicator (up to 3 pills, one per window) ----------
    Row {
        opacity: root.running ? root.presence : 0
        visible: opacity > 0.01
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.iconSize + 14
        spacing: 3

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Repeater {
            model: Math.min(root.windows.length, 3)
            Rectangle {
                width: (root.active && root.windows.length === 1) ? 14 : 5
                height: 3
                radius: 2
                color: root.active ? Theme.accent : Theme.muted
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    // ---------- tooltip ----------
    Rectangle {
        id: tip

        readonly property bool wanted: root.hovered && root.tipEnabled && !root.lifted && root.present
        property real slide: wanted ? 0 : 5
        Behavior on slide { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        opacity: wanted ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140 } }

        anchors.horizontalCenter: parent.horizontalCenter
        // rides above the magnified icon
        y: -height - 12 - Math.max(0, tile.height * (tile.scale - 1)) + slide
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

    // ---------- input ----------
    MouseArea {
        id: mouse
        anchors {
            fill: parent
            leftMargin: -root.hitPad
            rightMargin: -root.hitPad
            topMargin: -root.hitTop
        }
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        property real pressX: 0
        property bool dragMode: false

        function parentX(ev) {
            return mapToItem(root.parent, ev.x, ev.y).x;
        }

        onEntered: root.hoverMoved(mapToItem(root.parent, mouseX, mouseY).x)
        onExited: root.hoverLeft()

        onPressed: ev => {
            // x inside the item itself (not the padded hit area)
            pressX = ev.x - root.hitPad;
            dragMode = false;
        }

        onPositionChanged: ev => {
            if (!pressed) {
                root.hoverMoved(parentX(ev));
                return;
            }
            if (!root.draggable || !(ev.buttons & Qt.LeftButton)) return;
            if (!dragMode) {
                if (Math.abs(ev.x - root.hitPad - pressX) < 8) return;
                dragMode = true;
                root.dragStarted();
            }
            root.dragMoved(parentX(ev) - pressX);
        }

        onReleased: {
            if (dragMode) root.dragEnded();
        }

        onCanceled: {
            if (dragMode) {
                dragMode = false;
                root.dragEnded();
            }
        }

        onClicked: ev => {
            if (dragMode) {      // that was a drag, not a click
                dragMode = false;
                return;
            }
            if (ev.button === Qt.RightButton)
                root.menuRequested();
            else if (ev.button === Qt.MiddleButton)
                DockState.closeWindow(root.item);
            else
                DockState.activate(root.item);
        }
    }
}
