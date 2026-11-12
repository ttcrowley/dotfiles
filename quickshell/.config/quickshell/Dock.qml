import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    property int iconSize: 40
    property bool autoHide: true       // false = always visible
    property int hideDelay: 400        // ms after the mouse leaves
    property int bottomMargin: 10
    property int triggerWidth: 520     // width of the hover strip at the screen bottom
    property bool forced: false        // keybinding: keep the dock open until toggled again

    // Control from your compositor:  qs ipc call dock toggle | show | hide
    IpcHandler {
        target: "dock"
        function toggle(): void { root.forced = !root.forced; }
        function show(): void { root.forced = true; }
        function hide(): void { root.forced = false; }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            property bool shown: false
            property bool menuOpen: false
            property bool pickerOpen: false
            property var menuItem: null
            property real menuCenterX: 0
            readonly property bool revealed: !root.autoHide || shown || root.forced

            anchors { left: true; right: true; bottom: true }
            implicitHeight: 500
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell-dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: pickerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Only these areas receive mouse input; everything else clicks through.
            mask: Region {
                item: hit
                Region { item: menu }
                Region { item: picker }
            }

            Item {
                anchors.fill: parent

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
                        win.shown = false;
                        win.menuOpen = false;
                        win.pickerOpen = false;
                    }
                }

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
                    width: row.implicitWidth + 20
                    height: root.iconSize + 32
                    x: (parent.width - width) / 2
                    y: win.revealed ? parent.height - height - root.bottomMargin : parent.height + 6
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Row {
                        id: row
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: DockState.items

                            DockItem {
                                required property var modelData
                                item: modelData
                                iconSize: root.iconSize
                                tipEnabled: !win.menuOpen && !win.pickerOpen

                                onMenuRequested: {
                                    win.menuItem = modelData;
                                    win.menuCenterX = mapToItem(null, width / 2, 0).x;
                                    win.pickerOpen = false;
                                    win.menuOpen = true;
                                }
                            }
                        }

                        // divider
                        Item {
                            visible: DockState.items.length > 0
                            width: 9
                            height: root.iconSize + 20
                            Rectangle {
                                anchors.centerIn: parent
                                width: 1
                                height: root.iconSize * 0.6
                                color: Theme.border
                            }
                        }

                        // "all apps" button
                        Item {
                            width: root.iconSize + 14
                            height: root.iconSize + 20

                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: root.iconSize + 12
                                radius: 10
                                color: (appsMouse.containsMouse || win.pickerOpen) ? Theme.surface : "transparent"
                                border.width: 1
                                border.color: appsMouse.containsMouse ? Theme.border : "transparent"
                            }
                            Text {
                                x: (parent.width - width) / 2
                                y: 6 + (root.iconSize - height) / 2
                                text: "\udb80\udc3b"
                                color: win.pickerOpen ? Theme.accent : Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 22
                            }
                            MouseArea {
                                id: appsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    win.menuOpen = false;
                                    win.pickerOpen = !win.pickerOpen;
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

                // ---------------- app picker (add favorites / launch) ----------------
                Rectangle {
                    id: picker

                    readonly property var filtered: {
                        const q = search.text.trim().toLowerCase();
                        return Array.from(DesktopEntries.applications.values)
                            .filter(e => !e.noDisplay
                                && (q === ""
                                    || e.name.toLowerCase().includes(q)
                                    || (e.genericName ?? "").toLowerCase().includes(q)))
                            .sort((a, b) => a.name.localeCompare(b.name));
                    }

                    visible: win.pickerOpen
                    width: win.pickerOpen ? 340 : 0
                    height: win.pickerOpen ? 400 : 0
                    x: (parent.width - width) / 2
                    y: dock.y - height - 8
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    onVisibleChanged: {
                        if (visible) {
                            search.text = "";
                            search.forceActiveFocus();
                        }
                    }

                    TextField {
                        id: search
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                        height: 36
                        placeholderText: "Search apps…"
                        color: Theme.fg
                        placeholderTextColor: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        leftPadding: 12
                        background: Rectangle {
                            radius: 8
                            color: Theme.surface
                            border.width: 1
                            border.color: search.activeFocus ? Theme.accent : Theme.border
                        }
                        Keys.onEscapePressed: win.pickerOpen = false
                        onAccepted: {
                            if (picker.filtered.length > 0) {
                                picker.filtered[0].execute();
                                win.pickerOpen = false;
                            }
                        }
                    }

                    ListView {
                        id: list
                        anchors {
                            top: search.bottom
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: 10
                            topMargin: 8
                        }
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: ScriptModel { values: picker.filtered }

                        delegate: Item {
                            id: appRow
                            required property var modelData
                            readonly property bool pinned: DockState.favorites.indexOf(modelData.id) !== -1

                            width: list.width
                            height: 38

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: appMouse.containsMouse ? Theme.surface : "transparent"
                            }

                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    appRow.modelData.execute();
                                    win.pickerOpen = false;
                                }
                            }

                            IconImage {
                                id: appIcon
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 24
                                source: {
                                    const n = appRow.modelData.icon;
                                    if (!n) return Quickshell.iconPath("application-x-executable");
                                    if (n.startsWith("/")) return "file://" + n;
                                    return Quickshell.iconPath(n, "application-x-executable");
                                }
                            }

                            Text {
                                anchors {
                                    left: appIcon.right
                                    leftMargin: 10
                                    right: star.left
                                    rightMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: appRow.modelData.name
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }

                            Text {
                                id: star
                                anchors {
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: appRow.pinned ? "★" : "☆"
                                color: appRow.pinned ? Theme.accent : Theme.dim
                                font.pixelSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
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
