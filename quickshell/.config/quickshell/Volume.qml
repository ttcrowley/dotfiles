import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Grid {
    id: root
    flow: Grid.LeftToRight
    columns: BarState.vertical ? 1 : 2
    spacing: 0
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: Math.min(1, sink?.audio?.volume ?? 0)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool open: hover.hovered || sliderArea.pressed

    PwObjectTracker { objects: [root.sink] }

    function setVol(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    // Detects the pointer over the whole widget without stealing clicks
    HoverHandler { id: hover }

    // Scroll anywhere on the widget to change volume
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = 0.05
            root.setVol(root.vol + (event.angleDelta.y > 0 ? step : -step))
        }
    }

    // Icon: left click = mute, right click = pavucontrol
    Text {
        id: icon
        text: root.muted ? "\uf026" : root.vol < 0.5 ? "\uf027" : "\uf028"
        color: root.muted ? Theme.warn
             : iconArea.containsMouse ? Theme.fg
             : Theme.dim
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        font { family: Theme.font; pixelSize: Theme.fontSize }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) Quickshell.execDetached(["pavucontrol"])
                else if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }

    // Collapsible part: slider + percentage
    Item {
        id: extra
        clip: true
        // Horizontal: grows sideways. Vertical: grows downwards (just the % label).
        width: BarState.vertical ? content.implicitWidth : (root.open ? content.implicitWidth : 0)
        height: BarState.vertical ? (root.open ? content.implicitHeight : 0) : icon.implicitHeight
        opacity: root.open ? 1 : 0

        Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Row {
            id: content
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            leftPadding: BarState.vertical ? 0 : 8

            // Slider
            Item {
                id: slider
                visible: !BarState.vertical   // no room for the slider on a thin vertical bar
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                height: 18

                readonly property int handleSize: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.surface

                    Rectangle {
                        width: handle.x + handle.width / 2
                        height: parent.height
                        radius: 2
                        color: root.muted ? Theme.dim : Theme.accent
                    }
                }

                Rectangle {
                    id: handle
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.handleSize
                    height: slider.handleSize
                    radius: width / 2
                    x: root.vol * (slider.width - width)
                    color: root.muted ? Theme.muted : Theme.fg
                }

                MouseArea {
                    id: sliderArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function update(mouseX) {
                        const half = slider.handleSize / 2
                        root.setVol((mouseX - half) / (slider.width - slider.handleSize))
                    }

                    onPressed: mouse => update(mouse.x)
                    onPositionChanged: mouse => { if (pressed) update(mouse.x) }
                }
            }

            // Percentage (fixed width so the bar doesn't jiggle while dragging)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                text: Math.round(root.vol * 100) + "%"
                color: Theme.muted
                horizontalAlignment: BarState.vertical ? Text.AlignHCenter : Text.AlignRight
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
        }
    }
}
