import Quickshell
import Quickshell.Wayland
import QtQuick

// Gear button with a tray, same layout as PowerMenu:
//   Vertical/Horizontal bar  switch the bar orientation (was OrientationButton)
//   Light/Dark theme         flip Theme.dark (bar and dock follow)
//   Restart shell            kill every Quickshell instance and start a fresh one
//   Open config              Yazi (in kitty) on the Quickshell config folder
Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    property bool open: false

    // Where your Quickshell files live (opened in Yazi).
    property string configDir: "/home/crowley/.config/quickshell"

    // Kills every running instance (including stale ones), then starts a clean one.
    // setsid keeps it alive after Quickshell kills itself. If you start the shell
    // with extra flags (-c name, -p path), put them on the `qs -d` part.
    property var restartCommand: [
    "setsid", "-f", "sh", "-c",
    "pkill -x qs; pkill -x quickshell; sleep 0.5; qs -d; qs -p ~/.config/quickshell/dock -d"
]
    readonly property bool vertical: BarState.vertical

    // Horizontal bar: menu hangs under the bar, right-aligned.
    readonly property int menuTop: (root.QsWindow.window?.height ?? 0) + 10
    readonly property int menuRight: 12
    // Vertical bar: menu sits to the right of the bar, bottom-aligned
    // (+6 = the bar's own left margin, +10 = gap)
    readonly property int menuLeft: (root.QsWindow.window?.width ?? 0) + 6 + 10
    readonly property int menuBottom: 6

    Text {
        id: icon
        text: "\uf013"
        // gray normally, white on hover or while the menu is open
        color: (iconArea.containsMouse || root.open) ? Theme.accent : Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
        // the gear turns a little when the menu opens
        rotation: root.open ? 60 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: iconArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    component Entry: Rectangle {
        id: entry
        property string glyph
        property string label
        property var command          // optional: run detached
        property color tint: Theme.fg
        signal triggered              // optional: run QML code

        width: parent.width
        height: 32
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.border : "transparent"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 12

            Text {
                width: 18
                text: entry.glyph
                color: entry.tint
                horizontalAlignment: Text.AlignHCenter
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
            Text {
                text: entry.label
                color: Theme.fg
                font { family: Theme.font; pixelSize: Theme.fontSize }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.open = false
                if (entry.command)
                    Quickshell.execDetached(entry.command)
                entry.triggered()
            }
        }
    }

    // Transparent full-screen layer: any click outside the menu closes it
    PanelWindow {
        id: overlay
        visible: root.open
        screen: root.QsWindow.window?.screen ?? null
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        // Escape also closes it
        Item {
            focus: true
            Keys.onEscapePressed: root.open = false
        }

        Rectangle {
            id: menuBox
            x: root.vertical ? root.menuLeft : parent.width - width - root.menuRight
            y: root.vertical ? parent.height - height - root.menuBottom : root.menuTop
            width: 190
            height: menu.implicitHeight + 16
            radius: Theme.radius
            color: Theme.surface
            border { color: Theme.border; width: 1 }

            // Swallows clicks on the gaps between entries
            MouseArea { anchors.fill: parent }

            Column {
                id: menu
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Entry {
                    // Says where a click takes you:
                    // horizontal bar -> arrows-v (go vertical); vertical bar -> arrows-h
                    glyph: BarState.vertical ? "\uf07e" : "\uf07d"
                    label: BarState.vertical ? "Horizontal bar" : "Vertical bar"
                    onTriggered: BarState.toggle()
                }
                Entry {
                    // Says where a click takes you: sun while dark, moon while light
                    glyph: Theme.dark ? "\uf185" : "\uf186"
                    label: Theme.dark ? "Light theme" : "Dark theme"
                    onTriggered: Theme.toggle()
                }
                Entry {
                    glyph: "\uf01e"; label: "Restart shell"
                    command: root.restartCommand
                }
                Entry {
                    glyph: "\uf07b"; label: "Open config"
                    command: ["kitty", "yazi", root.configDir]
                }
            }
        }
    }
}
