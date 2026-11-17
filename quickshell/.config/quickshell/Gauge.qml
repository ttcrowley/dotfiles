import Quickshell
import QtQuick
import QtQuick.Shapes

// Circular gauge: grey track (unused) + colored arc (used), 0-100.
// The arc glides to new values instead of jumping.
Item {
    id: g

    property string label: ""
    property string icon: ""
    property string unit: "%"
    property int value: 0
    property color fillColor: Theme.accent

    readonly property real ratio: Math.max(0, Math.min(100, value)) / 100

    property int size: 20
    property int thickness: 2

    // What is actually drawn: eases toward `ratio` / `fillColor`
    property real shownRatio: ratio
    property color shownColor: fillColor
    Behavior on shownRatio { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    Behavior on shownColor { ColorAnimation { duration: 300 } }

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer   // Qt 6.6+; delete this line if it errors

        // unused (grey)
        ShapePath {
            strokeColor: Theme.border
            strokeWidth: g.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: g.size / 2
                centerY: g.size / 2
                radiusX: (g.size - g.thickness) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360
            }
        }

        // used (theme color)
        ShapePath {
            strokeColor: g.shownRatio > 0.001 ? g.shownColor : "transparent"
            strokeWidth: g.thickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: g.size / 2
                centerY: g.size / 2
                radiusX: (g.size - g.thickness) / 2
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * g.shownRatio
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: g.icon
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 9
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
    }

    PopupWindow {
        // Stay mapped until the fade-out has finished
        visible: area.containsMouse || tipBox.opacity > 0.01
        anchor.window: g.QsWindow.window
        // Below the gauge (horizontal bar) / to its right (vertical bar)
        anchor.edges: BarState.vertical ? Edges.Right : Edges.Bottom
        anchor.gravity: BarState.vertical ? Edges.Right : Edges.Bottom
        anchor.rect.x: {
            area.containsMouse   // re-evaluate each time the tooltip opens
            const p = g.mapToItem(null, 0, 0)
            return BarState.vertical ? p.x + g.width + 8 : p.x + g.width / 2
        }
        anchor.rect.y: {
            area.containsMouse
            const p = g.mapToItem(null, 0, 0)
            return BarState.vertical ? p.y + g.height / 2 : p.y + g.height + 8
        }
        anchor.rect.width: 1
        anchor.rect.height: 1

        implicitWidth: tip.implicitWidth + 20
        implicitHeight: tip.implicitHeight + 12
        color: "transparent"

        Rectangle {
            id: tipBox
            anchors.fill: parent
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusSmall

            opacity: area.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            Text {
                id: tip
                anchors.centerIn: parent
                text: g.icon + "  " + g.label + " " + g.value + g.unit
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
