import QtQuick

// Pomodoro page shown inside the Clock popup. All state lives in PomodoroService.
Item {
    id: root
    implicitHeight: col.implicitHeight

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

    Column {
        id: col
        width: parent.width
        spacing: 16

        // Phase + time (+ settings gear)
        Item {
            width: parent.width
            height: header.implicitHeight

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: "\uf013"
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

        // Session dots (filled = focus sessions done in this cycle)
        Item {
            width: parent.width
            height: 8

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: PomodoroService.cyclesBeforeLong

                    Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: index < PomodoroService.cycleDots ? Theme.accent : Theme.border
                    }
                }
            }
        }

        // Controls
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

        // Session lengths (toggle with the gear)
        Row {
            visible: root.showSettings
            width: parent.width

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

        Rectangle { width: parent.width; height: 1; color: Theme.surface }

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

        // Status line
        Text {
            id: status
            width: parent.width
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: Theme.fontSize - 2 }

            readonly property string err: PomodoroService.linkError !== ""
                                          ? PomodoroService.linkError : PomodoroService.musicError

            text: err !== "" ? err
                : PomodoroService.link === "" ? "Paste a link to play while focusing"
                : PomodoroService.playing ? "\uf001  Playing"
                : !PomodoroService.musicOn ? "Music off"
                : "Plays during focus"
            color: err !== "" ? Theme.warn
                 : PomodoroService.playing ? Theme.connected
                 : Theme.dim
        }
    }
}
