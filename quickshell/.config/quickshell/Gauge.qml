import Quickshell
import QtQuick

// Circular gauge: grey track (unused) + colored arc (used), 0-100
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

    implicitWidth: size
    implicitHeight: size

    onRatioChanged: canvas.requestPaint()
    onFillColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var lw = g.thickness
            var r = (width - lw) / 2
            var cx = width / 2
            var cy = height / 2
            var start = -Math.PI / 2

            ctx.lineWidth = lw

            // unused (grey)
            ctx.strokeStyle = Theme.border
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
            ctx.stroke()

            // used (theme color)
            if (g.ratio > 0) {
                ctx.strokeStyle = g.fillColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + Math.PI * 2 * g.ratio, false)
                ctx.stroke()
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
        visible: area.containsMouse
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
            anchors.fill: parent
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 6

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
