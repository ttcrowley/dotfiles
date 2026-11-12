pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Shared bar state. Every widget reads BarState.vertical, so all monitors'
// bars switch together and no property has to be passed down the tree.
// The choice is saved to disk and restored on the next start.
Singleton {
    id: root

    // false = horizontal bar at the top, true = vertical bar on the left
    property bool vertical: false

    // ~/.local/state/quickshell-bar-orientation  (honours $XDG_STATE_HOME)
    readonly property string stateFile:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/quickshell-bar-orientation"

    function set(v: bool): void {
        vertical = v
        file.setText(v ? "vertical" : "horizontal")
    }
    function toggle()        { set(!vertical) }
    function setVertical()   { set(true) }
    function setHorizontal() { set(false) }

    FileView {
        id: file
        path: root.stateFile
        blockLoading: true   // read before the bar's first frame, so there is no flash
        // Assign directly (not via set()) so loading doesn't rewrite the file.
        // On the very first run there is no file yet: stays horizontal.
        onLoaded: root.vertical = file.text().trim() === "vertical"
        onSaveFailed: err => console.warn("BarState: could not save orientation:", err)
    }
}
