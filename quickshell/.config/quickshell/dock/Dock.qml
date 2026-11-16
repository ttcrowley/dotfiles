import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    property int iconSize: 40
    property bool autoHide: true       // false = always visible
    property int hideDelay: 400        // ms after the mouse leaves
    property int bottomMargin: 24      // gap between the dock and the screen edge
    property int triggerWidth: 520     // width of the hover strip at the screen bottom
    property bool forced: false        // keep the dock open until toggled again
    property int searchWidth: 400      // width of the search bar (state 1); popup uses this too
    property int maxResults: 7         // visible rows in the results list
    property int resultHeight: 44
    property int wheelCooldown: 300    // ms between wheel-driven state changes

    // Screenshot buttons (utils state): window / area / screen -> hyprshot -> Satty -> clipboard.
    // The work is done by shot.sh next to this file.
    property string shotScript: Quickshell.env("HOME") + "/.config/quickshell/dock/shot.sh"
    property var shots: [
        { glyph: "\uf2d0", tip: "Window", mode: "window" },
        { glyph: "\uf125", tip: "Area",   mode: "region" },
        { glyph: "\uf108", tip: "Screen",  mode: "output" }
    ]

    // Other utils buttons. `action: "clipboard"` opens the clipboard history; a button
    // can also run a command via `cmd` (argv list), e.g.  cmd: ["sh", "-c", "some-command"]
    property var utils: [
        { glyph: "\uf0ea", tip: "Clipboard", action: "clipboard" }
    ]

    function runShot(mode) {
        Quickshell.execDetached(["sh", shotScript, mode]);
    }

    function runUtil(u) {
        if (u.action === "clipboard")
            root.clipboardRequested();
        else if (u.cmd && u.cmd.length > 0)
            Quickshell.execDetached(u.cmd);
        else
            console.log("dock: utils '" + u.tip + "' has no command yet");
    }

    // mode: 0 = favorites, 1 = search, 2 = utils
    signal launchRequested(string screenName, int mode)

    // Utils > Clipboard: shell.qml opens the ClipboardMenu
    signal clipboardRequested()

    // Separate instance, so address it by path:
    //   qs -p ~/.config/quickshell/dock ipc call dock toggle | show | hide | launcher | utils
    IpcHandler {
        target: "dock"
        function toggle(): void { root.forced = !root.forced; }
        function show(): void { root.forced = true; }
        function hide(): void { root.forced = false; }
        // Switch the focused monitor's dock to the search state (again = back to favorites)
        function launcher(): void {
            root.launchRequested(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "", 1);
        }
        function utils(): void {
            root.launchRequested(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "", 2);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            property bool shown: false
            property bool menuOpen: false
            property int mode: 0                      // 0 favorites, 1 search, 2 utils
            property var menuItem: null
            property real menuCenterX: 0
            readonly property bool launcherOpen: mode === 1
            readonly property bool utilsOpen: mode === 2
            readonly property bool revealed: !root.autoHide || shown || root.forced || launcherOpen || utilsOpen

            function setMode(m) {
                const n = Math.max(0, Math.min(2, m));
                if (n === mode) return;
                menuOpen = false;
                mode = n;
            }
            function closeLauncher() {
                mode = 0;
            }

            Connections {
                target: root
                function onLaunchRequested(name, m) {
                    if (name === "" || name === win.screen.name)
                        win.setMode(win.mode === m ? 0 : m);
                }
            }

            // Re-list the .desktop files that really exist, so removed apps drop out
            onRevealedChanged: if (revealed) DockState.refreshInstalled()

            onLauncherOpenChanged: {
                search.text = "";
                if (launcherOpen) {
                    DockState.refreshInstalled();
                    Qt.callLater(() => search.forceActiveFocus());
                } else {
                    search.focus = false;
                }
            }

            anchors { left: true; right: true; bottom: true }
            // Full height so a click-away catcher can cover the screen while a popup is open.
            // Input outside the mask below still clicks through.
            implicitHeight: win.screen.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell-dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Only these areas receive mouse input; everything else clicks through.
            mask: Region {
                item: hit
                Region { item: menu }
                Region { item: popup }
                Region { item: catcher }
            }

            Item {
                anchors.fill: parent

                // Click-away catcher: only exists while the menu or search is open
                MouseArea {
                    id: catcher
                    width: (win.launcherOpen || win.menuOpen) ? parent.width : 0
                    height: (win.launcherOpen || win.menuOpen) ? parent.height : 0
                    onClicked: {
                        win.menuOpen = false;
                        win.closeLauncher();
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            hideTimer.stop();
                            win.shown = true;
                        } else {
                            hideTimer.restart();
                        }
                    }
                }

                Timer {
                    id: hideTimer
                    interval: root.hideDelay
                    onTriggered: {
                        if (favs.dragKey !== "") {   // never hide mid-drag
                            hideTimer.restart();
                            return;
                        }
                        win.shown = false;
                        win.menuOpen = false;
                        win.mode = 0;          // always come back as favorites
                    }
                }

                Timer { id: wheelGate; interval: root.wheelCooldown }

                // Input area: thin strip when hidden, whole dock when shown
                Item {
                    id: hit
                    width: win.revealed ? dock.width + 40 : root.triggerWidth
                    height: win.revealed ? dock.height + root.bottomMargin + 6 : 4
                    x: (parent.width - width) / 2
                    y: parent.height - height
                }

                // ---------------- dock ----------------
                Rectangle {
                    id: dock
                    width: row.implicitWidth + 56
                    height: root.iconSize + 40
                    x: (parent.width - width) / 2
                    y: win.revealed ? parent.height - height - root.bottomMargin : parent.height + 6
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    // Mouse wheel over the dock cycles through the states (wheel down = next, loops)
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: ev => {
                            if (wheelGate.running || ev.angleDelta.y === 0) return;
                            win.setMode((win.mode + (ev.angleDelta.y < 0 ? 1 : 2)) % 3);
                            wheelGate.restart();
                        }
                    }

                    Row {
                        id: row
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        spacing: 0

                        // The dock's width follows whichever state is showing
                        Item {
                            id: pagesBox
                            height: root.iconSize + 20
                            width: win.mode === 0 ? favPage.implicitWidth
                                 : (win.mode === 1 ? searchPage.implicitWidth : utilsPage.implicitWidth)

                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                            // ---------- state 0: favorites + running apps ----------
                            DockPage {
                                id: favPage
                                index: 0
                                mode: win.mode
                                implicitWidth: Math.max(favs.targetWidth, 170)

                                DockFavorites {
                                    id: favs
                                    anchors.centerIn: parent
                                    iconSize: root.iconSize
                                    tipsEnabled: !win.menuOpen && win.mode === 0
                                    interactive: win.mode === 0

                                    onMenuRequested: (item, centerX) => {
                                        win.menuItem = item;
                                        win.menuCenterX = centerX;
                                        win.menuOpen = true;
                                    }
                                }

                                Text {
                                    visible: DockState.items.length === 0
                                    anchors.centerIn: parent
                                    text: "Scroll to search and pin apps"
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }

                            // ---------- state 1: search ----------
                            DockPage {
                                id: searchPage
                                index: 1
                                mode: win.mode
                                implicitWidth: root.searchWidth

                                Rectangle {
                                    y: 6
                                    width: parent.width
                                    height: root.iconSize
                                    radius: 12
                                    color: Theme.surface
                                    border.width: 1
                                    // idle: border blends into the fill; focused: a quiet mid-gray line
                                    border.color: search.activeFocus ? Theme.border : Theme.surface
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    Text {
                                        id: searchGlyph
                                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                        text: "\uf002"
                                        color: search.activeFocus ? Theme.muted : Theme.dim
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        font.family: Theme.font
                                        font.pixelSize: 15
                                    }

                                    TextField {
                                        id: search
                                        anchors {
                                            left: searchGlyph.right
                                            leftMargin: 10
                                            right: parent.right
                                            rightMargin: 12
                                            verticalCenter: parent.verticalCenter
                                        }
                                        height: parent.height - 6
                                        leftPadding: 0
                                        rightPadding: 0
                                        verticalAlignment: TextInput.AlignVCenter
                                        placeholderText: "Search apps…"
                                        placeholderTextColor: Theme.dim
                                        color: Theme.fg
                                        selectionColor: Theme.border
                                        selectedTextColor: Theme.accent
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        selectByMouse: true
                                        background: Item {}

                                        onTextChanged: list.currentIndex = 0

                                        Keys.onEscapePressed: win.closeLauncher()
                                        Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                                        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                                        Keys.onPressed: ev => {
                                            if (ev.modifiers & Qt.ControlModifier) {
                                                if (ev.key === Qt.Key_N) {
                                                    list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                                                    ev.accepted = true;
                                                } else if (ev.key === Qt.Key_P) {
                                                    list.currentIndex = Math.max(0, list.currentIndex - 1);
                                                    ev.accepted = true;
                                                }
                                            }
                                        }
                                        onAccepted: {
                                            const e = popup.results[list.currentIndex];
                                            if (e) {
                                                e.execute();
                                                win.closeLauncher();
                                            }
                                        }
                                    }
                                }
                            }

                            // ---------- state 2: utils ----------
                            DockPage {
                                id: utilsPage
                                index: 2
                                mode: win.mode
                                implicitWidth: Math.max(utilsRow.implicitWidth, 170)

                                Row {
                                    id: utilsRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // screenshot: window / area / screen
                                    Repeater {
                                        model: root.shots

                                        DockButton {
                                            required property var modelData
                                            required property int index
                                            iconSize: root.iconSize
                                            glyph: modelData.glyph
                                            tip: modelData.tip
                                            tipEnabled: win.mode === 2
                                            revealed: win.mode === 2
                                            revealDelay: index * 45
                                            onClicked: {
                                                root.runShot(modelData.mode);
                                                win.mode = 0;
                                                win.shown = false;   // slide the dock away before capturing
                                            }
                                        }
                                    }

                                    // Divider — grows from the middle as part of the cascade
                                    Item {
                                        id: dividerSlot
                                        width: 9
                                        height: root.iconSize + 20

                                        property bool _shown: false
                                        readonly property bool shown: win.mode === 2
                                        onShownChanged: {
                                            if (shown) dividerTimer.restart();
                                            else { dividerTimer.stop(); _shown = false; }
                                        }

                                        Timer {
                                            id: dividerTimer
                                            interval: 135   // 3 shots × 45 ms
                                            onTriggered: dividerSlot._shown = dividerSlot.shown
                                        }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 1
                                            height: (root.iconSize * 0.6) * (dividerSlot._shown ? 1 : 0)
                                            color: Theme.border
                                            opacity: dividerSlot._shown ? 1 : 0
                                            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Repeater {
                                        model: root.utils

                                        DockButton {
                                            required property var modelData
                                            required property int index
                                            iconSize: root.iconSize
                                            glyph: modelData.glyph
                                            tip: modelData.tip
                                            tipEnabled: win.mode === 2
                                            revealed: win.mode === 2
                                            revealDelay: (4 + index) * 45   // after the divider
                                            onClicked: {
                                                root.runUtil(modelData);
                                                win.mode = 0;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    // state dots: click one to jump straight to that state
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        spacing: 6

                        Repeater {
                            model: 3

                            Item {
                                id: dot
                                required property int index
                                readonly property bool on: win.mode === index
                                width: on ? 18 : 6
                                height: 10

                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: dot.on ? Theme.muted : Theme.border
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    onClicked: win.setMode(dot.index)
                                }
                            }
                        }
                    }
                }

                // ---------------- right-click menu ----------------
                Rectangle {
                    id: menu
                    readonly property var rows: win.menuItem ? DockState.menuRows(win.menuItem) : []

                    visible: win.menuOpen
                    width: win.menuOpen ? 240 : 0
                    height: win.menuOpen ? menuCol.implicitHeight + 16 : 0
                    x: Math.max(8, Math.min(parent.width - width - 8, win.menuCenterX - width / 2))
                    y: dock.y - height - 8
                    radius: 12
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    Column {
                        id: menuCol
                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 2

                        Repeater {
                            model: menu.rows

                            Item {
                                id: menuRow
                                required property var modelData
                                width: menuCol.width
                                height: modelData.sep ? 9 : 30

                                Rectangle {
                                    visible: menuRow.modelData.sep === true
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 1
                                    color: Theme.border
                                }

                                Rectangle {
                                    visible: menuRow.modelData.sep !== true
                                    anchors.fill: parent
                                    radius: 6
                                    color: rowMouse.containsMouse ? Theme.surface : "transparent"

                                    Text {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            margins: 10
                                        }
                                        text: menuRow.modelData.label ?? ""
                                        elide: Text.ElideRight
                                        color: menuRow.modelData.danger ? Theme.warn : Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 1
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: menuRow.modelData.sep !== true
                                        onClicked: {
                                            menuRow.modelData.run();
                                            win.menuOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------- search results (fades and slides in) ----------------
                Rectangle {
                    id: popup

                    readonly property var results: win.launcherOpen ? DockState.search(search.text) : []
                    readonly property int rows: Math.max(1, Math.min(results.length, root.maxResults))
                    readonly property real anchorX: dock.x + row.x + pagesBox.x + pagesBox.width / 2
                    // size collapses to 0 when fully faded out so the invisible popup never blocks clicks
                    readonly property bool live: opacity > 0.01

                    opacity: win.launcherOpen ? 1 : 0
                    visible: live
                    width: live ? 460 : 0
                    height: live ? rows * root.resultHeight + (rows - 1) * 2 + 24 : 0
                    x: Math.max(8, Math.min(parent.width - width - 8, anchorX - width / 2))
                    y: dock.y - height - 8
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height  { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    transform: Translate {
                        y: win.launcherOpen ? 0 : 12
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        visible: popup.results.length === 0
                        anchors.centerIn: parent
                        text: "No matching apps"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: 140
                        highlight: Rectangle {
                            width: list.width
                            height: root.resultHeight
                            radius: 8
                            color: Theme.surface
                        }
                        model: ScriptModel { values: popup.results }

                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                       delegate: Item {
                            id: appRow
                            required property var modelData
                            required property int index
                            readonly property bool current: ListView.isCurrentItem
                            readonly property bool pinned: DockState.favorites.indexOf(modelData.id) !== -1
                            readonly property string subtitle: modelData.genericName || modelData.comment || ""

                            width: list.width
                            height: root.resultHeight

                            // Full-row hit area stays put — it must not move with the nudge.
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: list.currentIndex = appRow.index
                                onClicked: {
                                    appRow.modelData.execute();
                                    win.closeLauncher();
                                }
                            }

                            // Visual content. Width/height set explicitly (NOT anchors.fill)
                            // so `x` can animate — anchors.fill would pin x and kill the nudge.
                            Item {
                                id: content
                                width: parent.width
                                height: parent.height
                                x: appRow.current ? 6 : 0
                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                IconImage {
                                    id: appIcon
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 28
                                    scale: appRow.current ? 1.18 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    source: {
                                        const n = appRow.modelData.icon;
                                        if (!n) return Quickshell.iconPath("application-x-executable");
                                        if (n.startsWith("/")) return "file://" + n;
                                        return Quickshell.iconPath(n, "application-x-executable");
                                    }
                                }

                                Column {
                                    anchors {
                                        left: appIcon.right
                                        leftMargin: 12
                                        right: star.left
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        width: parent.width
                                        text: appRow.modelData.name
                                        elide: Text.ElideRight
                                        color: appRow.current ? Theme.fg : Theme.muted
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        visible: appRow.subtitle !== ""
                                        width: parent.width
                                        text: appRow.subtitle
                                        elide: Text.ElideRight
                                        color: Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 3
                                    }
                                }

                                // pin / unpin from the dock
                                Text {
                                    id: star
                                    visible: opacity > 0.01
                                    opacity: (appRow.pinned || appRow.current) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                    anchors {
                                        right: parent.right
                                        rightMargin: 14
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: appRow.pinned ? "★" : "☆"
                                    color: appRow.pinned ? Theme.muted : Theme.dim
                                    font.pixelSize: 18

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        enabled: appRow.pinned || appRow.current
                                        onClicked: appRow.pinned
                                            ? DockState.unpin(appRow.modelData.id)
                                            : DockState.pin(appRow.modelData.id)
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
