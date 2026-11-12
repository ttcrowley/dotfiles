import Quickshell
import Quickshell.Hyprland
import QtQuick

// Standalone Pomodoro button for the bar: tomato icon (+ time while a session
// is active). Click to open the Pomodoro popup.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: BarState.vertical ? row.implicitHeight : 24

    readonly property bool active: PomodoroService.running || PomodoroService.progress > 0
    readonly property bool focused: PomodoroService.running && PomodoroService.phase === "focus"

    // Nerd Font "Pomicons" glyph (U+E000-E00A range) - swap the code to change the icon
    // (the leading "| " is a separator, only used on the horizontal bar)
    readonly property string icon: BarState.vertical ? "\ue002" : "| \ue002"
    readonly property color color: focused ? Theme.accent : Theme.dim

    // Icon + time side by side (horizontal) or stacked (vertical)
    Grid {
        id: row
        anchors.centerIn: parent
        flow: Grid.LeftToRight
        columns: BarState.vertical ? 1 : 2
        spacing: BarState.vertical ? 2 : 6
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Text {
            text: root.icon
            color: root.color
            font { family: Theme.font; pixelSize: Theme.fontSize + 6 }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: root.active
            text: PomodoroService.timeText
            color: root.color
            font { family: Theme.font; pixelSize: BarState.vertical ? Theme.fontSize - 3 : Theme.fontSize; bold: true }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.open = !popup.open
    }

    // Click outside the popup (or on another window) closes it
    HyprlandFocusGrab {
        // the bar window is included so clicking the toggle doesn't close-then-reopen
        windows: [popup, root.QsWindow.window]
        active: popup.open
        onCleared: popup.open = false
    }

    SlidePopup {
        id: popup
        anchorItem: root
        barWindow: root.QsWindow.window
        contentWidth: 280
        contentHeight: pomodoro.implicitHeight + 2 * padding

        Pomodoro {
            id: pomodoro
            anchors.fill: parent
        }
    }
}
