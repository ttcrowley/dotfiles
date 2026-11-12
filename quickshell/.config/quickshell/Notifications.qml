import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Native notification daemon (replaces dunst).
//  - Popups slide down from the top edge, newest at the bottom of the stack,
//    and at most `maxVisible` are shown at once.
//  - Everything stays in a history you open from the bar's bell
//    (NotificationBell.qml) or with:  qs ipc call notifications toggleHistory
//  - A soft keyboard "thock" plays when a popup appears (sounds/thock.wav).
Scope {
    id: root

    // Do Not Disturb input. shell.qml binds this to the Pomodoro focus phase.
    // Manual toggles live in NotifState.manualDnd, so they never replace that
    // binding. Either one being true turns DND on (dndActive).
    property bool dnd: false
    readonly property bool dndActive: dnd || NotifState.manualDnd

    // App names that ignore DND (critical urgency always does).
    // Pomodoro must be listed: its "Break over" notice fires right as focus
    // (and therefore DND) starts, and you do want to see that one.
    property var dndExempt: ["Pomodoro"]

    // Distance from the top of the screen to where popups start. Popups are
    // clipped at this line, so they slide down out of it and back up into it.
    property int topOffset: 48

    // Unused now (popups are centered); kept so an old `barWidth: ...` line
    // in shell.qml doesn't break loading.
    property int barWidth: 0

    property int cardWidth: 340
    property int gap: 8
    property int radius: 10
    property int defaultTimeout: 5000   // ms, when the app doesn't ask for one

    // Most popups on screen at once. Older ones slide away into the history.
    property int maxVisible: 4

    // History is trimmed to this many notifications (oldest dismissed first).
    property int maxHistory: 50

    // Played when a popup appears (needs pw-play or paplay).
    property string soundFile: Quickshell.shellDir + "/sounds/thock.wav"

    // History panel geometry. The offsets keep it clear of the bar:
    // horizontal bar = 6 + 34 + 8, vertical bar = 6 + 40 + 8.
    property int panelWidth: 380
    property int panelHeight: 460
    property int panelOffsetH: 48
    property int panelOffsetV: 54

    readonly property bool vertical: BarState.vertical

    // Every notification still alive (popup closed or not).
    readonly property var history: server.trackedNotifications
    // Same list, newest first (what the panel shows).
    readonly property var historyNewestFirst: server.trackedNotifications.values.slice().reverse()

    // id -> arrival time, for the "2m" labels and for telling a fresh
    // notification from one that merely survived a Quickshell reload.
    property var arrivals: ({})
    property real now: Date.now()

    function clearAll() {
        const list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++)
            list[i].dismiss();
        NotifState.unread = 0;
    }

    // Keep the history from growing forever.
    function trim() {
        const list = server.trackedNotifications.values;
        const extra = list.length - maxHistory;
        if (extra <= 0)
            return;
        const old = list.slice(0, extra);
        for (let i = 0; i < old.length; i++)
            old[i].dismiss();
    }

    function bypassDnd(n) {
        return n.urgency === NotificationUrgency.Critical
            || dndExempt.indexOf(n.appName) !== -1;
    }

    function popupAllowed(n) {
        return !dndActive || bypassDnd(n);
    }

    function isFresh(id) {
        const t = arrivals[id];
        return t !== undefined && Date.now() - t < 3000;
    }

    // Run the default action (if any), then remove the notification.
    function activate(n) {
        const acts = n.actions;
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") {
                acts[i].invoke();
                break;
            }
        }
        n.dismiss();
    }

    function ago(id) {
        const t = arrivals[id];
        if (t === undefined)
            return "";
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function playSound() {
        if (NotifState.soundEnabled && !sound.running)
            sound.running = true;
    }

    // Plays the file; skipped if the previous one is still sounding, so a burst
    // of notifications gives one thock instead of a stack of them.
    Process {
        id: sound
        command: ["sh", "-c", "pw-play \"$1\" 2>/dev/null || paplay \"$1\" 2>/dev/null", "sh", root.soundFile]
    }

    // Refresh the "2m" labels while the panel is open.
    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: NotifState.historyOpen
        onTriggered: root.now = Date.now()
    }

    // Let the bell and IPC see the real DND state.
    Binding {
        target: NotifState
        property: "dnd"
        value: root.dndActive
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            root.arrivals[n.id] = Date.now();
            n.tracked = true;
            root.trim();
            if (!NotifState.historyOpen)
                NotifState.unread++;
            if (root.popupAllowed(n))
                root.playSound();
        }
    }

    // qs ipc call notifications toggleDnd
    // qs ipc call notifications clearAll
    // qs ipc call notifications toggleHistory
    // qs ipc call notifications toggleSound
    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            NotifState.manualDnd = !NotifState.manualDnd;
        }
        function clearAll(): void {
            root.clearAll();
        }
        function toggleHistory(): void {
            NotifState.toggleHistory();
        }
        function toggleSound(): void {
            NotifState.soundEnabled = !NotifState.soundEnabled;
        }
    }

    // ───────────────────────── Popups ─────────────────────────
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
                    required property int index

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property bool sticky: critical && modelData.expireTimeout <= 0

                    // Only the newest `maxVisible` notifications may have a popup.
                    readonly property bool inWindow:
                        index >= server.trackedNotifications.values.length - root.maxVisible

                    property bool entered: false          // flips on after creation -> slide-in
                    // Decided once, when the notification arrives. Suppressed (DND)
                    // and stale ones go straight to history and never pop up later.
                    property bool shown: false
                    readonly property bool open: shown && entered && inWindow

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

                    Component.onCompleted: {
                        shown = root.popupAllowed(modelData) && root.isFresh(modelData.id);
                        entered = true;
                    }

                    // Pushed out by newer ones: slide away for good (it stays in history).
                    onInWindowChanged: {
                        if (!inWindow)
                            shown = false;
                    }

                    Connections {
                        target: root
                        function onDndActiveChanged() {
                            if (root.dndActive && !root.bypassDnd(entry.modelData))
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
                                if (mouse.button === Qt.RightButton)
                                    entry.shown = false;
                                else
                                    root.activate(entry.modelData);
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

    // ───────────────────────── History panel ─────────────────────────
    // Slides out of the bar's edge: down from a top bar, right from a left bar.
    // Click anywhere outside it to close.
    HyprlandFocusGrab {
        windows: [panelWin]
        active: panelWin.visible && NotifState.historyOpen
        onCleared: {
            NotifState.historyOpen = false;
            NotifState.lastClosedAt = Date.now();
        }
    }

    PanelWindow {
        id: panelWin

        // 0 = tucked behind the bar, 1 = fully out.
        property real slide: NotifState.historyOpen ? 1 : 0
        Behavior on slide {
            NumberAnimation {
                duration: 220
                easing.type: NotifState.historyOpen ? Easing.OutCubic : Easing.InCubic
            }
        }

        visible: NotifState.historyOpen || slide > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notification-history"

        // Horizontal bar: top-right, under the bell. Vertical bar: bottom-left,
        // beside it. Only the anchored edges' margins apply.
        anchors {
            top: !root.vertical
            right: !root.vertical
            bottom: root.vertical
            left: root.vertical
        }
        margins {
            top: root.panelOffsetH
            right: 12
            bottom: 6
            left: root.panelOffsetV
        }
        implicitWidth: root.panelWidth
        implicitHeight: Math.min(root.panelHeight, (panelWin.screen ? panelWin.screen.height : 900) - 80)

        Item {
            anchors.fill: parent
            clip: true   // the panel slides out from behind this edge

            Rectangle {
                id: panel
                width: parent.width
                height: parent.height
                radius: root.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.border

                x: root.vertical ? -(width + root.gap) * (1 - panelWin.slide) : 0
                y: root.vertical ? 0 : -(height + root.gap) * (1 - panelWin.slide)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "Notifications"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        Text {
                            text: server.trackedNotifications.values.length
                            visible: server.trackedNotifications.values.length > 0
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        HeaderButton {
                            cornerRadius: root.radius - 4
                            label: "DND"
                            active: NotifState.dnd
                            onClicked: NotifState.manualDnd = !NotifState.manualDnd
                        }
                        HeaderButton {
                            cornerRadius: root.radius - 4
                            label: "Sound"
                            active: NotifState.soundEnabled
                            onClicked: NotifState.soundEnabled = !NotifState.soundEnabled
                        }
                        HeaderButton {
                            cornerRadius: root.radius - 4
                            label: "Clear"
                            onClicked: root.clearAll()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                    }

                    // List
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            visible: server.trackedNotifications.values.length === 0
                            text: "No notifications"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }

                        ListView {
                            id: list
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.historyNewestFirst

                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                                width: list.width
                                height: rowContent.implicitHeight + 16
                                radius: root.radius - 2
                                color: rowArea.containsMouse ? Theme.surface : "transparent"
                                border.width: 1
                                border.color: row.critical ? Theme.warn : Theme.border

                                // Click the row: run the default action and remove it.
                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activate(row.modelData)
                                }

                                RowLayout {
                                    id: rowContent
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: 8
                                    }
                                    spacing: 8

                                    Image {
                                        readonly property string src: row.modelData.image !== ""
                                            ? row.modelData.image
                                            : (row.modelData.appIcon !== ""
                                                ? Quickshell.iconPath(row.modelData.appIcon, true)
                                                : "")
                                        visible: src !== ""
                                        source: src
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        Layout.alignment: Qt.AlignTop
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                Layout.fillWidth: true
                                                text: row.modelData.appName
                                                color: Theme.dim
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 3
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: root.ago(row.modelData.id)
                                                color: Theme.dim
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 3
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.modelData.summary
                                            visible: text !== ""
                                            color: row.critical ? Theme.warn : Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize - 1
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: row.modelData.body
                                            visible: text !== ""
                                            textFormat: Text.StyledText
                                            color: Theme.muted
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize - 2
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Remove just this one.
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: "\u00d7"
                                        color: closeArea.containsMouse ? Theme.fg : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 2

                                        MouseArea {
                                            id: closeArea
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: row.modelData.dismiss()
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
