import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls

Item {
    id: root
    // Horizontal: width follows the time only; the date overflows centered on hover.
    // Vertical: time and date are both two stacked lines, so size to the larger one.
    implicitWidth: BarState.vertical ? Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth)
                                     : timeLabel.implicitWidth
    readonly property bool hovered: hover.hovered
    implicitHeight: BarState.vertical ? Math.max(timeLabel.implicitHeight, dateLabel.implicitHeight)
                                      : timeLabel.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    HoverHandler { id: hover }

    // Time (default)
    Text {
        id: timeLabel
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: BarState.vertical
            ? clock.date.toLocaleString(Theme.locale, "HH") + "\n" + clock.date.toLocaleString(Theme.locale, "mm")
            : clock.date.toLocaleString(Theme.locale, "HH:mm")
        color: Theme.muted
        font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }

        opacity: hover.hovered ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // Date (on hover)
    Text {
        id: dateLabel
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: BarState.vertical
            ? (clock.date.toLocaleString(Theme.locale, "dd") + "\n" + clock.date.toLocaleString(Theme.locale, "MMM")).replace(/\./g, "")
            : clock.date.toLocaleString(Theme.locale, "ddd, d 'de' MMMM").replace(/\./g, "")
        color: Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }

        opacity: hover.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.open = !popup.open
    }

    // Calendar popup
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
        contentHeight: cal.implicitHeight + 2 * padding

        property date shown: new Date()

        Column {
            id: cal
            anchors.fill: parent
            spacing: 12

            Row {
                width: parent.width
                Text {
                    text: "\uf053"; color: Theme.accent
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    width: 30
                    MouseArea { anchors.fill: parent
                        onClicked: popup.shown = new Date(popup.shown.getFullYear(), popup.shown.getMonth() - 1, 1) }
                }
                Text {
                    text: popup.shown.toLocaleDateString(Theme.locale, "MMMM 'de' yyyy")
                    color: Theme.fg; horizontalAlignment: Text.AlignHCenter
                    width: parent.width - 60
                    font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                }
                Text {
                    text: "\uf054"; color: Theme.accent; horizontalAlignment: Text.AlignRight
                    font { family: Theme.font; pixelSize: Theme.fontSize }
                    width: 30
                    MouseArea { anchors.fill: parent
                        onClicked: popup.shown = new Date(popup.shown.getFullYear(), popup.shown.getMonth() + 1, 1) }
                }
            }

            DayOfWeekRow {
                width: parent.width
                locale: Theme.locale
                delegate: Text {
                    required property var model
                    text: model.shortName
                    color: Theme.dim; horizontalAlignment: Text.AlignHCenter
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
            }

            MonthGrid {
                id: grid
                width: parent.width
                spacing: 2
                month: popup.shown.getMonth()
                year: popup.shown.getFullYear()
                locale: Theme.locale
                delegate: Item {
                    id: cell
                    required property var model
                    implicitWidth: 28
                    implicitHeight: 28

                    // White circle behind the current day
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: width / 2
                        color: Theme.accent
                        visible: cell.model.today
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.model.day
                        // dark number on the white circle for the current day
                        color: cell.model.today ? Theme.bg
                             : cell.model.month === grid.month ? Theme.fg
                             : Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: cell.model.today }
                    }
                }
            }
        }
    }
}
