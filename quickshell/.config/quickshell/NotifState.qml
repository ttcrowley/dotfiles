pragma Singleton
import Quickshell
import QtQuick

// Shared notification state, so Notifications.qml (the daemon + panel),
// the bar's NotificationBell and IPC calls all talk about the same things.
Singleton {
    // History panel open/closed.
    property bool historyOpen: false

    // Notifications that arrived while the panel was closed (the bell badge).
    // Opening the panel marks them all as seen.
    property int unread: 0

    // Do Not Disturb as it really is right now (manual OR Pomodoro focus).
    // Written by Notifications.qml; read-only for everyone else.
    property bool dnd: false

    // Manual DND switch (bell right-click, panel button, IPC). Kept apart from
    // Notifications.dnd so it never overwrites the Pomodoro binding in shell.qml.
    property bool manualDnd: false

    property bool soundEnabled: true

    // When the panel was last closed by a click outside it. The bell uses this
    // so the click that closes the panel doesn't instantly reopen it.
    property real lastClosedAt: 0

    function toggleHistory() {
        if (!historyOpen && Date.now() - lastClosedAt < 250)
            return;
        historyOpen = !historyOpen;
    }

    onHistoryOpenChanged: if (historyOpen) unread = 0
}
