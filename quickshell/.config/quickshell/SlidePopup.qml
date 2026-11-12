import Quickshell
import QtQuick

// Popup that hangs flush off the bar and slides out of its edge.
//   vertical bar  -> slides left-to-right out of the bar's right edge
//   horizontal bar -> slides top-to-bottom out of the bar's bottom edge
// Put the popup's content inside it as children (they fill a 'body' item).
PopupWindow {
    id: popup

    required property Item anchorItem      // the bar widget this popup belongs to
    required property var barWindow        // pass root.QsWindow.window
    property bool open: false
    property int contentWidth: 260
    property int contentHeight: 256
    property int cornerRadius: 10
    // Inner breathing room between the panel edge and its content
    property int padding: 18
    property int openDuration: 380
    property int closeDuration: 280

    default property alias contentData: body.data

    // 0 = fully tucked behind the bar, 1 = fully out
    property real slide: open ? 1 : 0
    // Custom bezier curves instead of the built-in easings:
    //   open  - fast start that settles very gently (ease-out-quint)
    //   close - soft start AND soft landing (no abrupt stop at the bar edge)
    Behavior on slide {
        NumberAnimation {
            duration: popup.open ? popup.openDuration : popup.closeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: popup.open
                ? [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
                : [0.45, 0.0, 0.25, 1.0, 1.0, 1.0]
        }
    }

    // Stay mapped until the slide-out finishes
    visible: open || slide > 0.001

    anchor.window: popup.barWindow
    // Flush against the bar (no gap) so it reads as part of it
    anchor.rect.x: {
        popup.open   // re-evaluate each time the popup opens
        const w = popup.barWindow?.width ?? 0
        if (BarState.vertical) return w
        const centered = popup.anchorItem.mapToItem(null, 0, 0).x - (width - popup.anchorItem.width) / 2
        return Math.max(4, Math.min(centered, w - width - 4))
    }
    anchor.rect.y: {
        popup.open
        const h = popup.barWindow?.height ?? 0
        if (!BarState.vertical) return h
        const centered = popup.anchorItem.mapToItem(null, 0, 0).y - (height - popup.anchorItem.height) / 2
        return Math.max(4, Math.min(centered, h - height - 4))
    }

    implicitWidth: contentWidth
    implicitHeight: contentHeight
    color: "transparent"

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height

        // The window edge touching the bar is the "doorway": the panel starts
        // fully outside it and slides in, so it appears to come out of the bar.
        x: BarState.vertical ? -(1 - popup.slide) * width : 0
        y: BarState.vertical ? 0 : -(1 - popup.slide) * height

        // Fades in over the first half of the slide so the panel never
        // "cuts" in at the window edge
        opacity: Math.min(1, popup.slide * 2)

        color: Theme.bg   // same as the bar, so there is no visible seam

        // Only the corners away from the bar are rounded
        radius: popup.cornerRadius
        topLeftRadius: 0
        topRightRadius: BarState.vertical ? popup.cornerRadius : 0
        bottomLeftRadius: BarState.vertical ? 0 : popup.cornerRadius
        bottomRightRadius: popup.cornerRadius

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: popup.padding
        }
    }
}
