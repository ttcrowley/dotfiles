import QtQuick

// Single-line text field used by the task editor.
// Clicking anywhere in the box focuses the input.
Rectangle {
    id: field

    property alias text: ti.text
    property alias input: ti
    property alias validator: ti.validator
    property alias hints: ti.inputMethodHints
    property string placeholder: ""
    signal accepted()
    signal escaped()

    height: 36
    radius: 8
    color: Theme.surface
    border { color: ti.activeFocus ? Theme.accent : Theme.border; width: 1 }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: ti.forceActiveFocus()
    }

    TextInput {
        id: ti
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.bg
        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
        onAccepted: field.accepted()
        Keys.onEscapePressed: field.escaped()
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: ti.text.length === 0
        text: field.placeholder
        color: Theme.dim
        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
    }
}
