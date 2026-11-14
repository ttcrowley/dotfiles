import QtQuick

// Pomodoro page shown inside the Clock popup. All state lives in PomodoroService.
Item {
    id: root
    // The popup WINDOW is never resized per frame (that flickers on Wayland). It stays at the
    // "settings open" height while the gear animates and only changes once, at the start of
    // opening / the end of closing. Only the visible panel animates, via shownHeight.
    implicitHeight: col.implicitHeight - setT * settingsExtra
                    + ((showSettings || setT > 0) ? settingsExtra : 0)
    readonly property real shownHeight: col.implicitHeight + (editorCol.implicitHeight - col.implicitHeight) * editT

    readonly property color phaseColor: PomodoroService.phase === "focus" ? Theme.accent : Theme.connected
    readonly property string phaseLabel: PomodoroService.phase === "focus" ? "FOCUS"
                                       : PomodoroService.phase === "short" ? "SHORT BREAK"
                                       : "LONG BREAK"

    component IconButton: Text {
        id: btn
        signal clicked()
        property bool hot: false

        width: 32
        height: 30
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: area.containsMouse ? Theme.fg : (hot ? Theme.accent : Theme.muted)
        font { family: Theme.font; pixelSize: Theme.fontSize + 4 }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    property bool showSettings: false
    // 0 = session lengths hidden, 1 = shown; animated, drives reveal + gear rotation
    property real setT: showSettings ? 1 : 0
    Behavior on setT { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
    readonly property real settingsExtra: settingsRow.implicitHeight + 16

    // Task editor (index -1 = new task)
    property bool editing: false
    // 0 = main view, 1 = task editor; animated, drives height + crossfade
    property real editT: editing ? 1 : 0
    Behavior on editT { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
    property int editIndex: -1

    function openEditor(i) {
        editIndex = i
        titleField.text = i >= 0 ? PomodoroService.tasks[i].text : ""
        countStepper.value = i >= 0 ? PomodoroService.tasks[i].target : 1
        editing = true
        Qt.callLater(() => titleField.input.forceActiveFocus())
    }

    function saveEditor() {
        const title = titleField.text.trim()
        if (title === "") { titleField.input.forceActiveFocus(); return }
        const n = countStepper.value
        if (editIndex >= 0) PomodoroService.updateTask(editIndex, title, n)
        else PomodoroService.addTask(title, n)
        editing = false
    }

    Column {
        id: col
        width: parent.width
        spacing: 16
        opacity: Math.max(0, 1 - root.editT * 2)   // fades out in the first half
        visible: opacity > 0
        enabled: !root.editing

        // Phase + time (+ settings gear)
        Item {
            width: parent.width
            height: header.implicitHeight

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: "\uf013"
                rotation: root.setT * 90
                color: root.showSettings ? Theme.accent : Theme.dim
                font { family: Theme.font; pixelSize: Theme.fontSize }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showSettings = !root.showSettings
                }
            }

            Column {
                id: header
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.phaseLabel
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 3; letterSpacing: 1.5 }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: PomodoroService.timeText
                    color: root.phaseColor
                    font { family: Theme.font; pixelSize: 40; bold: true }
	    }
                           Item {
                    width: parent.width
                    height: visible ? 20 : 0
                    visible: PomodoroService.currentTask >= 0

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "Current task:"
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: Theme.fontSize - 3 }
                        }
                        Text {
                            width: Math.min(implicitWidth, root.width - 110)
                            elide: Text.ElideRight
                            text: PomodoroService.currentTask >= 0
                                  ? PomodoroService.tasks[PomodoroService.currentTask].text : ""
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: Theme.fontSize - 3; bold: true }
                        }
                    }
                }
            }
        }

        // Progress bar
        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surface

            Rectangle {
                width: parent.width * PomodoroService.progress
                height: parent.height
                radius: 2
                color: root.phaseColor
            }
        }

        // Controls (+ session lengths, revealed by the gear)
        Item {
            id: controlsBox
            width: parent.width
            height: 40 + root.setT * root.settingsExtra
            clip: true

            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    IconButton { text: "\uf0e2"; onClicked: PomodoroService.reset() }
                    IconButton {
                        width: 44
                        hot: true
                        text: PomodoroService.running ? "\uf04c" : "\uf04b"
                        font.pixelSize: Theme.fontSize + 8
                        onClicked: PomodoroService.toggle()
                    }
                    IconButton { text: "\uf051"; onClicked: PomodoroService.skip() }
                }
            }

            // Session lengths
            Row {
                id: settingsRow
                y: 40 + 16
                width: parent.width
                opacity: root.setT
                enabled: root.showSettings

                DurationStepper {
                    width: parent.width / 3
                    label: "Focus"
                    value: PomodoroService.focusMin
                    step: 5
                    onAdjust: delta => PomodoroService.setDuration("focus", PomodoroService.focusMin + delta, 5)
                }
                DurationStepper {
                    width: parent.width / 3
                    label: "Short break"
                    value: PomodoroService.shortBreakMin
                    onAdjust: delta => PomodoroService.setDuration("short", PomodoroService.shortBreakMin + delta)
                }
                DurationStepper {
                    width: parent.width / 3
                    label: "Long break"
                    value: PomodoroService.longBreakMin
                    onAdjust: delta => PomodoroService.setDuration("long", PomodoroService.longBreakMin + delta)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.surface }


        // Tasks: click a row to make it current, the box to finish/reset it,
        // the pencil (or double-click) to edit
        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: taskTitle.implicitHeight

                Text {
                    id: taskTitle
                    text: "\uf0ae  Tasks"
                    color: Theme.muted
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    visible: PomodoroService.tasks.length > 0

                    Text {
                        text: PomodoroService.tasksDone + "/" + PomodoroService.tasks.length
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                    Text {
                        visible: PomodoroService.tasksDone > 0
                        text: "\uf014"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PomodoroService.clearDoneTasks()
                        }
                    }
                }
            }

            ListView {
                id: taskList
                width: parent.width
                height: Math.min(contentHeight, 150)
                visible: count > 0
                clip: true
                spacing: 2
                interactive: contentHeight > height
                model: PomodoroService.tasks

                delegate: Item {
                    id: taskRow
                    required property var modelData
                    required property int index
                    readonly property bool done: modelData.count >= modelData.target
                    readonly property bool current: index === PomodoroService.currentTask

                    width: taskList.width
                    height: 32

                    HoverHandler { id: rowHover }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: taskRow.current ? Theme.surface : "transparent"
                        border { color: taskRow.current ? Theme.border : "transparent"; width: 1 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PomodoroService.pickTask(taskRow.index)
                        onDoubleClicked: root.openEditor(taskRow.index)
                    }

                    Rectangle {
                        id: box
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 5
                        color: taskRow.done ? Theme.accent : "transparent"
                        border { color: taskRow.done ? Theme.accent : Theme.muted; width: 1 }

                        Text {
                            anchors.centerIn: parent
                            visible: taskRow.done
                            text: "\uf00c"
                            color: Theme.bg
                            font { family: Theme.font; pixelSize: Theme.fontSize - 5; bold: true }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PomodoroService.toggleTask(taskRow.index)
                        }
                    }

                    Text {
                        anchors.left: box.right
                        anchors.leftMargin: 10
                        anchors.right: countText.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: taskRow.modelData.text
                        color: taskRow.done ? Theme.dim : taskRow.current ? Theme.fg : Theme.muted
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize - 1
                            strikeout: taskRow.done
                        }
                    }

                    Text {
                        id: countText
                        anchors.right: actions.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: taskRow.modelData.count + "/" + taskRow.modelData.target
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }

                    // Edit + delete, only while hovering the row
                    Row {
                        id: actions
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        opacity: rowHover.hovered ? 1 : 0
                        enabled: rowHover.hovered

                        Text {
                            text: "\uf040"
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEditor(taskRow.index)
                            }
                        }
                        Text {
                            text: "\uf00d"
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PomodoroService.removeTask(taskRow.index)
                            }
                        }
                    }
                }
            }

            // "Add a new task" button -> opens the editor
            Rectangle {
                width: parent.width
                height: 32
                radius: 8
                color: "transparent"
                border { color: Theme.border; width: 1 }

                Text {
                    anchors.centerIn: parent
                    text: "\uf067  Add a new task"
                    color: addArea.containsMouse ? Theme.fg : Theme.dim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openEditor(-1)
                }
            }
        }

        // Music header + on/off
        Item {
            width: parent.width
            height: musicTitle.implicitHeight

            Text {
                id: musicTitle
                text: "\uf001  Focus music"
                color: Theme.muted
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }
            Text {
                anchors.right: parent.right
                text: PomodoroService.musicOn ? "\uf205" : "\uf204"
                color: PomodoroService.musicOn ? Theme.accent : Theme.dim
                font { family: Theme.font; pixelSize: Theme.fontSize + 2 }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PomodoroService.musicOn = !PomodoroService.musicOn
                }
            }
        }

        // Link field: type + Enter, or use the paste button (reads the clipboard)
        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: Theme.surface
            border { color: input.activeFocus ? Theme.accent : Theme.border; width: 1 }

            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: input.forceActiveFocus() }

            Row {
                id: fieldButtons
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    visible: PomodoroService.link !== ""
                    text: "\uf00d"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PomodoroService.clearLink()
                    }
                }
                Text {
                    text: "\uf0ea"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PomodoroService.paste()
                    }
                }
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: fieldButtons.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                selectByMouse: true
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.bg
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                text: PomodoroService.link
                onAccepted: { if (PomodoroService.submitLink(text)) focus = false }
            }

            Text {
                anchors.left: input.left
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: "YouTube link…"
                color: Theme.dim
                font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
            }

            Connections {
                target: PomodoroService
                function onLinkChanged() { input.text = PomodoroService.link }
            }
        }

        // Music volume (drag, or scroll anywhere on the row)
        Item {
            id: volRow
            width: parent.width
            height: 22

            readonly property int vol: PomodoroService.musicVolume

            Text {
                id: volIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                text: volRow.vol === 0 ? "\uf026" : volRow.vol < 50 ? "\uf027" : "\uf028"
                color: Theme.dim
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }

            Item {
                id: slider
                anchors.left: volIcon.right
                anchors.leftMargin: 6
                anchors.right: volText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
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
                        color: Theme.accent
                    }
                }

                Rectangle {
                    id: handle
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.handleSize
                    height: slider.handleSize
                    radius: width / 2
                    x: volRow.vol / 100 * (slider.width - width)
                    color: Theme.fg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function update(mouseX) {
                        const half = slider.handleSize / 2
                        PomodoroService.setVolume((mouseX - half) / (slider.width - slider.handleSize) * 100)
                    }

                    onPressed: mouse => update(mouse.x)
                    onPositionChanged: mouse => { if (pressed) update(mouse.x) }
                }
            }

            Text {
                id: volText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                text: volRow.vol + "%"
                color: Theme.muted
                horizontalAlignment: Text.AlignRight
                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => PomodoroService.setVolume(volRow.vol + (event.angleDelta.y > 0 ? 5 : -5))
            }
        }

     }

    // ── Task editor (covers the popup while open) ───────────
    Rectangle {
        id: editor
        anchors.fill: parent
        visible: root.editing || root.editT > 0
        opacity: Math.max(0, root.editT * 2 - 1)   // fades in during the second half
        enabled: root.editing
        color: Theme.bg
        z: 10

        MouseArea { anchors.fill: parent }   // swallow clicks so nothing underneath fires

        Column {
            id: editorCol
            width: parent.width
            spacing: 16

            Item {
                width: parent.width
                height: 24

                Text {
                    text: root.editIndex >= 0 ? "Edit Task" : "New Task"
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: Theme.fontSize + 2; bold: true }
                }
                Text {
                    anchors.right: parent.right
                    text: "\uf00d"
                    color: Theme.muted
                    font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editing = false
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "Task title"
                    color: Theme.muted
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2; bold: true }
                }
                PomodoroField {
                    id: titleField
                    width: parent.width
                    placeholder: "What are you working on?"
                    onAccepted: root.saveEditor()
                    onEscaped: root.editing = false
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "Expected pomodoros"
                    color: Theme.muted
                    font { family: Theme.font; pixelSize: Theme.fontSize - 2; bold: true }
                }
                Row {
                    spacing: 14

                    PomodoroStepper {
                        id: countStepper
                        onAccepted: root.saveEditor()
                        onEscaped: root.editing = false
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "sessions"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 2 }
                    }
                }
            }

            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.right: parent.right
                    spacing: 10

                    PomodoroButton { label: "Cancel"; onClicked: root.editing = false }
                    PomodoroButton { label: "Save"; primary: true; onClicked: root.saveEditor() }
                }
            }
        }
    }
}
