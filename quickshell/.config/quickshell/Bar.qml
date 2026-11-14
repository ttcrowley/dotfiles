import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand   // lets popup text fields take keyboard focus
    required property var modelData
    screen: modelData

    readonly property bool vertical: BarState.vertical

    // Horizontal: top edge, full width.  Vertical: left edge, full height.
    anchors {
        top: true
        left: true
        right: !bar.vertical
        bottom: bar.vertical
    }
    margins {
        top: 6
        left: bar.vertical ? 6 : 0
        bottom: bar.vertical ? 6 : 0
    }
    // Explicit size on both axes. (Requesting 0 and letting the compositor
    // stretch the surface did not re-apply when switching back to horizontal.)
    // Vertical height = screen height minus the 6px top + 6px bottom margins.
    implicitWidth: bar.vertical ? 40 : bar.screen.width
    implicitHeight: bar.vertical ? bar.screen.height - 12 : 34
    color: Theme.bg

    // Row of widgets in horizontal mode, column in vertical mode
    component Group: Grid {
        columns: bar.vertical ? 1 : Math.max(1, children.length)
        flow: Grid.LeftToRight
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }

    Item {
        anchors.fill: parent

        // ── Start: top (vertical) / left (horizontal) ──
        Group {
            spacing: bar.vertical ? 16 : 30

            // Plain x/y (not conditional anchors: those left stale anchors behind
            // when toggling, which made the widgets pile up)
            x: bar.vertical ? (parent.width - width) / 2 : 12
            y: bar.vertical ? 12 : (parent.height - height) / 2

            ArchLogo {}
            Workspaces {}
            ActiveWindow {}   // hidden in vertical mode (too wide)
        }

        // ── Center ──
        Clock {
            id: clock
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
        }

        PomodoroWidget {
            // Right of the clock (horizontal) / below it (vertical)
            x: bar.vertical ? (parent.width - width) / 2 : clock.x + clock.width + 12
            y: bar.vertical ? clock.y + clock.height + 12 : (parent.height - height) / 2

            // Horizontal only: hide while the clock shows the date so they never overlap
            opacity: (!bar.vertical && clock.hovered) ? 0 : 1
            enabled: bar.vertical || !clock.hovered
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ── End: bottom (vertical) / right (horizontal) ──
        Group {
            spacing: bar.vertical ? 14 : 16

            x: bar.vertical ? (parent.width - width) / 2 : parent.width - width - 12
            y: bar.vertical ? parent.height - height - 12 : (parent.height - height) / 2

            Stats {}
            Volume {}
            Network {}
	    ExtraButtons {}            
	    PowerMenu {}
        }
    }
}


