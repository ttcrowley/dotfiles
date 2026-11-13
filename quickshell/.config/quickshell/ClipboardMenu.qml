import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Clipboard history menu backed by cliphist.
//
//   qs ipc call clipboard toggle | show | hide
//
// Keys:  Up/Down move · Enter copy · Shift+Delete remove entry · Esc close
// Mouse: click row = copy · x = remove entry · "Clear all" = wipe (asks twice)
PanelWindow {
    id: root

    // ── State ──────────────────────────────────────────────
    property bool open: false
    property var entries: []          // parsed `cliphist list` lines
    property string query: ""
    property int cur: 0               // highlighted row
    property bool confirmWipe: false
    property var thumbReady: ({})     // id -> true once the file exists
    property var thumbWanted: []      // [{id, ext}] from the latest list
    property var thumbInflight: []    // ids being decoded right now

    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-cliphist"

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        return q === "" ? root.entries
                        : root.entries.filter(e => e.text.toLowerCase().includes(q));
    }
    onFilteredChanged: cur = Math.max(0, Math.min(cur, filtered.length - 1))

    // ── Window: full-screen transparent overlay (click outside = close) ──
    function pickScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i];
        return list[0];
    }

    screen: pickScreen()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || card.opacity > 0.01

    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Actions ────────────────────────────────────────────
    function reload() { lister.running = true }

    function show() {
        query = "";
        search.text = "";
        cur = 0;
        confirmWipe = false;
        open = true;
        reload();
        Qt.callLater(() => search.forceActiveFocus());
    }

    function hide() {
        open = false;
        confirmWipe = false;
    }

    function choose(i) {
        const e = filtered[i];
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id]);
        hide();
    }

    function remove(i) {
        const e = filtered[i];
        if (!e) return;
        mutator.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", e.raw];
        mutator.running = true;
    }

    function wipe() {
        if (!confirmWipe) {
            confirmWipe = true;
            confirmTimer.restart();
            return;
        }
	confirmWipe = false;
	thumbReady = ({});
        thumbWanted = [];
        mutator.command = ["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", thumbDir];
        mutator.running = true;
    }

    function handleKey(e) {
        const n = filtered.length;
        if (e.key === Qt.Key_Escape) {
            hide();
            e.accepted = true;
        } else if (e.key === Qt.Key_Down) {
            if (n > 0) cur = Math.min(cur + 1, n - 1);
            list.positionViewAtIndex(cur, ListView.Contain);
            e.accepted = true;
        } else if (e.key === Qt.Key_Up) {
            if (n > 0) cur = Math.max(cur - 1, 0);
            list.positionViewAtIndex(cur, ListView.Contain);
            e.accepted = true;
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            choose(cur);
            e.accepted = true;
        } else if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier)) {
            remove(cur);
            e.accepted = true;
        }
    }

    // `cliphist list` -> "<id>\t<preview>" per line. Images look like
    // "[[ binary data 12 KiB png 800x600 ]]".
    function parse(t) {
        const out = [];
        const imgs = [];
        for (const line of t.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 1) continue;
            const id = line.slice(0, tab);
            const txt = line.slice(tab + 1);
            const m = txt.match(/^\[\[ binary data (.+?) (png|jpe?g|bmp|gif|webp|tiff?) (\d+x\d+) \]\]$/);
            out.push({
                id: id,
                raw: line,
                text: txt,
                image: m !== null,
                ext: m ? m[2] : "",
                info: m ? (m[1] + " · " + m[3]) : ""
            });
            if (m && imgs.length < 40) imgs.push({ id: id, ext: m[2] });
        }
        entries = out;
        thumbWanted = imgs;
        startThumbs();
    }

    function startThumbs() {
        if (thumbs.running) return;
        const missing = thumbWanted.filter(t => !thumbReady[t.id]);
        if (missing.length === 0) return;
        thumbInflight = missing.map(t => t.id);
        thumbs.command = [
            "sh", "-c",
            'd=$1; shift; mkdir -p "$d"; for e in "$@"; do id=${e%%:*}; f="$d/$id.${e#*:}"; [ -s "$f" ] || cliphist decode "$id" > "$f"; done',
            "sh", thumbDir
        ].concat(missing.map(t => t.id + ":" + t.ext));
        thumbs.running = true;
    }

    // ── Processes ──────────────────────────────────────────
    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Process {
        id: mutator
        onExited: root.reload()
    }

    Process {
        id: thumbs
        onExited: {
            const r = Object.assign({}, root.thumbReady);
            for (const id of root.thumbInflight) r[id] = true;
            root.thumbReady = r;
            root.thumbInflight = [];
            root.startThumbs();
        }
    }
    
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmWipe = false
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open ? root.hide() : root.show() }
        function show(): void   { root.show() }
        function hide(): void   { root.hide() }
    }

    // ── UI ─────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Rectangle {
        id: card
        width: 440
        height: col.implicitHeight + 2
        x: (parent.width - width) / 2
        // Centered for the tallest the menu can get (search + 384 list + footer),
        // so the search box stays put while the list grows/shrinks as you type.
        y: Math.max(52, (parent.height - 464) / 2) + (root.open ? 0 : -8)
        radius: 6
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        opacity: root.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // swallow clicks so they don't reach the click-outside area
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            x: 1
            y: 1
            width: card.width - 2
            spacing: 0

            // ── Search ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "\uf002"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: search
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            color: Theme.fg
                            selectionColor: Theme.border
                            selectedTextColor: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            clip: true
                            focus: true
                            onTextChanged: { root.query = text; root.cur = 0 }
                            Keys.onPressed: (e) => root.handleKey(e)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Search clipboard…"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface }

            // ── Entries ──
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: root.filtered.length === 0 ? 64 : Math.min(contentHeight + 8, 384)
                topMargin: 4
                bottomMargin: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: root.filtered }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.cur

                    width: list.width
                    height: modelData.image ? 56 : 34
                    color: selected ? Theme.surface : "transparent"

                    // click = copy, hover = highlight (only on real mouse movement)
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: root.cur = row.index
                        onClicked: root.choose(row.index)
                    }

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: Theme.accent
                        visible: row.selected
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        // text rows: small glyph
                        Text {
                            visible: !row.modelData.image
                            text: "\uf15c"
                            color: row.selected ? Theme.muted : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }

                        // image rows: thumbnail
                        Item {
                            visible: row.modelData.image
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: thumb.status !== Image.Ready
                                text: "\uf03e"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 2
                            }
                            Image {
                                id: thumb
                                anchors.fill: parent
                                anchors.margins: 1
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(88, 88)
                                source: (row.modelData.image && root.thumbReady[row.modelData.id])
                                        ? "file://" + root.thumbDir + "/" + row.modelData.id + "." + row.modelData.ext
                                        : ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.image ? "Image" : row.modelData.text
                                color: row.selected ? Theme.accent : Theme.fg
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                visible: row.modelData.image
                                text: row.modelData.info
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }

                        // remove this entry
                        Text {
                            visible: row.selected
                            text: "\uf00d"
                            color: delArea.containsMouse ? Theme.warn : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize

                            MouseArea {
                                id: delArea
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                onClicked: root.remove(row.index)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.entries.length === 0 ? "Clipboard is empty" : "No matches"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface }

            // ── Footer ──
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        text: root.filtered.length + (root.query !== "" ? " of " + root.entries.length : "")
                              + (root.filtered.length === 1 ? " item" : " items")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Text {
                        visible: !root.confirmWipe
                        text: "Enter copy · Shift+Del remove"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: clearLabel.implicitWidth + 20
                        Layout.preferredHeight: 22
                        radius: 3
                        color: clearArea.containsMouse ? Theme.surface : "transparent"
                        border.width: 1
                        border.color: root.confirmWipe ? Theme.warn : Theme.border

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: root.confirmWipe ? "Click again to confirm" : "\uf1f8  Clear all"
                            color: root.confirmWipe ? Theme.warn : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.entries.length > 0
                            onClicked: root.wipe()
                        }
                    }
                }
            }
        }
    }
}
