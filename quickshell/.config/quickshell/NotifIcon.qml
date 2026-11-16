import Quickshell
import QtQuick

// The icon of a notification, with a fallback chain:
//   1. the picture the app sent (image-data / image-path hint)
//   2. the icon name or path the app put in the notification
//   3. the icon of the app's .desktop entry (found by the desktop-entry hint or the app name)
//   4. a plain bell on the shell's palette, so it is never blank or a "missing icon" box
// A candidate that doesn't exist or fails to load just moves on to the next one.
Item {
    id: root

    required property var notif      // a Quickshell Notification
    property int size: 40

    implicitWidth: size
    implicitHeight: size

    // "" when the theme has no such icon (instead of Qt's missing-icon placeholder)
    function resolve(name) {
        if (!name) return "";
        if (name.startsWith("/")) return "file://" + name;
        if (name.startsWith("file://") || name.startsWith("image://")) return name;
        return Quickshell.iconPath(name, true);
    }

    function entryIcon() {
        let e = null;
        if (notif.desktopEntry)
            e = DesktopEntries.byId(notif.desktopEntry) ?? DesktopEntries.heuristicLookup(notif.desktopEntry);
        if (!e && notif.appName)
            e = DesktopEntries.heuristicLookup(notif.appName);
        return e ? (e.icon ?? "") : "";
    }

    // Image hints that point into /tmp (Satty sends a copy of the screenshot there) are
    // deleted as soon as the app exits: the popup sometimes catches them in time and the
    // history panel never does. Skipping them keeps the icon the same everywhere.
    // Set to false if you would rather keep such previews.
    property bool skipTempImages: true

    // Set to true to print what each notification sent (see `qs log`).
    property bool debug: false

    // Only pictures that can really load. image://icon/... is skipped on purpose: Qt draws
    // its magenta/black "missing icon" checkerboard for it when the file is gone, and that
    // counts as a successful load, so we could never fall back from it.
    function usableImage(s) {
        if (!s) return false;
        if (s.startsWith("image://qsimage")) return true;      // raw pixels sent over D-Bus
        if (skipTempImages && s.indexOf("/tmp/") !== -1) return false;
        return s.startsWith("/") || s.startsWith("file://");
    }

    readonly property var sources: {
        const out = [];
        const add = s => { if (s && out.indexOf(s) === -1) out.push(s); };
        const img = (notif.image ?? "").toString();
        if (usableImage(img)) add(img);
        add(resolve(notif.appIcon));
        add(resolve(entryIcon()));
        return out;
    }

    Component.onCompleted: {
        if (debug)
            console.log("NotifIcon:", JSON.stringify({
                image: (notif.image ?? "").toString(),
                appIcon: notif.appIcon,
                desktopEntry: notif.desktopEntry,
                entryIcon: entryIcon(),
                sources: sources
            }));
    }

    property int tryIndex: 0
    onSourcesChanged: tryIndex = 0
    readonly property string current: tryIndex < sources.length ? sources[tryIndex] : ""

    Image {
        anchors.fill: parent
        visible: root.current !== "" && status === Image.Ready
        source: root.current
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        onStatusChanged: if (status === Image.Error) root.tryIndex++
    }

    // default notification icon
    Rectangle {
        anchors.fill: parent
        visible: root.current === ""
        radius: root.size / 4
        color: Theme.surface

        Text {
            anchors.centerIn: parent
            text: "\uf0f3"      // bell (Nerd Font), same glyph as the bar's NotificationBell
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Math.round(root.size * 0.5)
        }
    }
}
