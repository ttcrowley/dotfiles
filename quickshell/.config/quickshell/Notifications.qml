import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Native notification daemon (replaces dunst).
// Popups slide out of the bar's edge, left to right, like the other popups.
Scope {
    id: root

    // Do Not Disturb: hides non-critical popups (they stay in `history`).
    // Bind it to your Pomodoro, e.g.  dnd: pomodoro.running
    property bool dnd: false

    // App names that ignore DND (critical urgency always does).
    // Pomodoro must be listed: its "Break over" notice fires right as focus
    // (and therefore DND) starts, and you do want to see that one.
    property var dndExempt: ["Pomodoro"]

    // Distance from the top of the screen to where popups start. Popups are
    // clipped at this line, so they slide down out of it and back up into it.
    // Set it to your bar's height when the bar is horizontal at the top.
    property int topOffset: 48

    // Unused now (popups are centered); kept so an old `barWidth: ...` line
    // in shell.qml doesn't break loading.
    property int barWidth: 0

    property int cardWidth: 340
    property int gap: 8
    property int radius: 10
    property int defaultTimeout: 5000   // ms, when the app doesn't ask for one

    // Every notification still alive (popup closed or not).
    readonly property var history: server.trackedNotifications

    function clearAll() {
        const list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++)
            list[i].dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => n.tracked = true
    }

    // qs ipc call notifications toggleDnd
    // qs ipc call notifications clearAll
    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function clearAll(): void {
            root.clearAll();
        }
    }

    PanelWindow {
        id: win

        // Always mapped: the Column only computes its height once the window
        // is shown, so tying visibility to it never fires. The mask below
        // makes the empty window invisible and click-through.
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"

        // Anchored top + bottom only, so the compositor centers it horizontally.
        anchors {
            top: true
            bottom: true
        }
        margins.top: root.topOffset
        implicitWidth: root.cardWidth + root.gap * 2

        // Only the cards take clicks; everything else passes through.
        mask: Region {
            item: column
        }

        Column {
            id: column
            x: root.gap
            y: root.gap
            width: root.cardWidth
            spacing: root.gap

            Repeater {
                model: server.trackedNotifications

                delegate: Item {
                    id: entry
                    required property var modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property bool sticky: critical && modelData.expireTimeout <= 0
                    readonly property bool bypassDnd: critical
                        || root.dndExempt.indexOf(modelData.appName) !== -1

                    property bool entered: false          // flips on after creation -> slide-in
                    property bool shown: !(root.dnd && !bypassDnd)
                    readonly property bool open: shown && entered

                    width: column.width
                    height: open ? card.height : 0
                    visible: open || card.y > -card.height
                    clip: true   // each card slides out of its own slot, top-down

                    Behavior on height {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Component.onCompleted: entered = true

                    Connections {
                        target: root
                        function onDndChanged() {
                            if (root.dnd && !entry.bypassDnd)
                                entry.shown = false;
                        }
                    }

                    Timer {
                        interval: entry.modelData.expireTimeout > 0
                            ? entry.modelData.expireTimeout * 1000
                            : root.defaultTimeout
                        running: entry.open && !entry.sticky && !hover.hovered
                        onTriggered: entry.shown = false
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: content.implicitHeight + 24
                        radius: root.radius
                        color: Theme.bg
                        border.width: 1
                        border.color: entry.critical ? Theme.warn : Theme.border

                        y: entry.open ? 0 : -(height + root.gap)
                        Behavior on y {
                            NumberAnimation {
                                duration: 220
                                easing.type: entry.open ? Easing.OutCubic : Easing.InCubic
                            }
                        }

                        HoverHandler {
                            id: hover
                        }

                        // Left click: run the default action (if any) and dismiss.
                        // Right click: just hide the popup, keep it in history.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    entry.shown = false;
                                    return;
                                }
                                const acts = entry.modelData.actions;
                                for (let i = 0; i < acts.length; i++) {
                                    if (acts[i].identifier === "default") {
                                        acts[i].invoke();
                                        break;
                                    }
                                }
                                entry.modelData.dismiss();
                            }
                        }

                        RowLayout {
                            id: content
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 12
                            }
                            spacing: 10

                            Image {
                                readonly property string src: entry.modelData.image !== ""
                                    ? entry.modelData.image
                                    : (entry.modelData.appIcon !== ""
                                        ? Quickshell.iconPath(entry.modelData.appIcon, true)
                                        : "")
                                visible: src !== ""
                                source: src
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                Layout.alignment: Qt.AlignTop
                                sourceSize: Qt.size(80, 80)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.appName
                                    visible: text !== ""
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 3
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.summary
                                    visible: text !== ""
                                    color: entry.critical ? Theme.warn : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.body
                                    visible: text !== ""
                                    textFormat: Text.StyledText
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }

                                // Action buttons ("default" is handled by clicking the card).
                                RowLayout {
                                    Layout.topMargin: 4
                                    spacing: 6
                                    visible: entry.modelData.actions.length > 1
                                        || (entry.modelData.actions.length === 1
                                            && entry.modelData.actions[0].identifier !== "default")

                                    Repeater {
                                        model: entry.modelData.actions

                                        delegate: Rectangle {
                                            id: btn
                                            required property var modelData
                                            visible: modelData.identifier !== "default"
                                            implicitWidth: label.implicitWidth + 16
                                            implicitHeight: label.implicitHeight + 8
                                            radius: root.radius - 4
                                            color: btnArea.containsMouse ? Theme.surface : "transparent"
                                            border.width: 1
                                            border.color: btnArea.containsMouse ? Theme.dim : Theme.border

                                            Text {
                                                id: label
                                                anchors.centerIn: parent
                                                text: btn.modelData.text
                                                color: Theme.fg
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 2
                                            }

                                            MouseArea {
                                                id: btnArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    btn.modelData.invoke();
                                                    entry.modelData.dismiss();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
