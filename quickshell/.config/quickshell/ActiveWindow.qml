import Quickshell.Wayland
import QtQuick

// Focused window title. Horizontal bar: plain text.
// Vertical bar: the same text rotated 90 degrees so it runs along the bar.
Item {
    id: root

    readonly property bool vertical: BarState.vertical

    readonly property var win: ToplevelManager.activeToplevel
    readonly property string appId: win?.appId ?? ""
    readonly property string title: win?.title ?? ""

    // ── Tuning ──────────────────────────────────────────────
    // Longest the text may get along the bar before it is elided.
    // Vertical space is shared with the logo, workspaces and the centered clock.
    readonly property real maxLength: vertical ? 220 : 320
    // -90 reads bottom-to-top (like a book spine); use 90 for top-to-bottom.
    readonly property real rotationDeg: -90
    // Extra space above the title in the vertical bar, on top of the Group
    // spacing, to push it away from the workspaces toward the bar's center.
    readonly property real gapBefore: vertical ? 28 : 0

    visible: label.text !== ""

    // The rotated text occupies swapped width/height in the layout
    implicitWidth: vertical ? label.height : label.width
    implicitHeight: vertical ? label.width + gapBefore : label.height
    width: implicitWidth
    height: implicitHeight

    Text {
        id: label

        // Show the window title; fall back to the app id if the title is empty
        text: root.title !== "" ? root.title : root.appId

        width: Math.min(implicitWidth, root.maxLength)
        elide: Text.ElideRight
        color: Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }

        // Rotates around its own center, so position the unrotated box such that
        // its center lands in the middle of the (swapped) area below the gap
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? root.gapBefore + width / 2 - height / 2 : 0
        rotation: root.vertical ? root.rotationDeg : 0
    }
}
