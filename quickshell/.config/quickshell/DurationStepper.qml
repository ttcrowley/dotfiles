import QtQuick

// Small "− 25m +" control. Click the buttons or scroll over it.
Column {
    id: root

    property string label
    property int value
    property int step: 1
    signal adjust(int delta)

    spacing: 4

    Text {
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        color: Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Text {
            width: 20
            height: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "\uf068"
            color: minusArea.containsMouse ? Theme.fg : Theme.muted
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjust(-root.step)
            }
        }

        Text {
            width: 34
            height: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.value + "m"
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize - 1; bold: true }
        }

        Text {
            width: 20
            height: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "\uf067"
            color: plusArea.containsMouse ? Theme.fg : Theme.muted
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }

            MouseArea {
                id: plusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjust(root.step)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.adjust(event.angleDelta.y > 0 ? root.step : -root.step)
    }
}
