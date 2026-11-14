import QtQuick

// "−  3  +" number picker: round buttons with the number between them.
// Click the buttons or scroll over it; you can also click the number to type.
Row {
    id: root

    property int value: 1
    property int from: 1
    property int to: 99
    property alias input: ti
    signal accepted()
    signal escaped()

    spacing: 10

    function step(d) { value = Math.max(from, Math.min(to, value + d)) }

    Rectangle {
        width: 30
        height: 30
        radius: 15
        color: minusArea.containsMouse ? Theme.border : Theme.surface
        opacity: root.value > root.from ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "\uf068"
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
        }
        MouseArea {
            id: minusArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.step(-1)
        }
    }

    Item {
        width: 40
        height: 30

        TextInput {
            id: ti
            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            validator: IntValidator { bottom: root.from; top: root.to }
            inputMethodHints: Qt.ImhDigitsOnly
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.bg
            font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }

            text: String(root.value)
            onTextEdited: {
                const n = parseInt(text)
                if (!isNaN(n)) root.value = Math.max(root.from, Math.min(root.to, n))
            }
            onEditingFinished: text = String(root.value)
            onActiveFocusChanged: if (activeFocus) selectAll()
            onAccepted: root.accepted()
            Keys.onEscapePressed: root.escaped()
        }
    }

    Rectangle {
        width: 30
        height: 30
        radius: 15
        color: plusArea.containsMouse ? Theme.border : Theme.surface
        opacity: root.value < root.to ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "\uf067"
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
        }
        MouseArea {
            id: plusArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.step(1)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.step(event.angleDelta.y > 0 ? 1 : -1)
    }
}
