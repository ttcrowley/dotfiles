import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property string kind: "none"
    property string name: ""

    Process {
        id: proc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "none", name = ""
                for (const l of this.text.trim().split("\n")) {
                    const p = l.split(":")
                    if (p[1]?.startsWith("connected") && (p[0] === "wifi" || p[0] === "ethernet")) {
                        kind = p[0]; name = p[2]; break
                    }
                }
                root.kind = kind
                root.name = name
            }
        }
    }


    Process {
    command: ["nmcli", "monitor"]
    running: true
    stdout: SplitParser {
        onRead: proc.running = true
    }
}

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: proc.running = true
    }

Text {
    id: label
    text: root.kind === "wifi" ? "\uf1eb"
        : root.kind === "ethernet" ? "\udb83\udc9d"
        : "\uf071"
	color: root.kind === "none" ? Theme.warn : Theme.connected
	font { family: Theme.font; pixelSize: Theme.fontSize + 2 }
}

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
    }
}
