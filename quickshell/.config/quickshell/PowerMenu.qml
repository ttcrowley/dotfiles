import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    property bool open: false

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
        text: "\uf011"
        // gray normally, white while the menu is open, red only on mouse over
        color: iconArea.containsMouse ? Theme.warn
             : root.open ? Theme.accent
             : Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize + 2}
        Behavior on color { ColorAnimation { duration: 150 } }
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
        property var command
        property color tint: Theme.fg

        width: parent.width
        height: 32
        radius: 6
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
                Quickshell.execDetached(entry.command)
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
            width: 170
            height: menu.implicitHeight + 16
            radius: 10
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
                    glyph: "\uf2f5"; label: "Logout"
                    command: ["sh", "-c", "loginctl terminate-user \"$USER\""]
                }
                Entry {
                    glyph: "\uf021"; label: "Reboot"
                    command: ["systemctl", "reboot"]
                }
                Entry {
                    glyph: "\uf011"; label: "Shutdown"
                    tint: Theme.warn
                    command: ["systemctl", "poweroff"]
                }
            }
        }
    }
}
