import QtQuick

// The favorites state of the dock: pinned apps (drag to reorder) followed by running
// apps that aren't pinned.
//
//  * One delegate per app, kept alive across changes, so items slide to their new
//    slots, fade in when they appear and fade out when they leave.
//  * Dock-style hover magnification: the icon under the cursor grows, its neighbours
//    grow a little less. Set `magnify` to 1.0 to turn it off.
//  * Drag a pinned app sideways to reorder; the others make room as you pass them.
Item {
    id: root

    property int iconSize: 40
    // Was 8. Must be >= (iconSize + 14) * magnify - iconSize - 14
    // so a fully-magnified tile still fits in its slot without touching its neighbours.
    property int spacing: 16
    property bool tipsEnabled: true
    property bool interactive: true          // false while another dock state is showing

    // ---- tweakables ----
    property real magnify: 1.25              // scale of the icon under the cursor (1.0 = off)
    property real magnifyRadius: 110         // px: how far the effect reaches along the dock
    property int slideDuration: 220          // ms: items sliding to their slots

    signal menuRequested(var item, real centerX)

    readonly property real slotW: iconSize + 14 + spacing
    readonly property var blankItem: ({ id: "", name: "", icon: "", windows: [], pinned: false })

    // key order of the apps that are staying, key -> slot number, how many are pinned
    property var order: []
    property var slots: ({})
    property int pinnedCount: 0

    readonly property int count: order.length
    readonly property real targetWidth: Math.max(0, count * slotW - spacing)

    // cursor x in this item's coordinates (far away = not hovering)
    property real cursorX: -100000

    // drag state
    property string dragKey: ""
    property int dragFrom: 0                 // slot the dragged app started in
    property int dragTo: 0                   // slot it would drop into right now
    property real dragX: 0                   // where the dragged app is drawn
    property bool dragFollow: false          // true = dragged app follows the cursor, no easing

    implicitWidth: targetWidth
    width: targetWidth
    height: iconSize + 20

    // same duration/easing as the dock's own width animation, so the icons don't jolt
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    onInteractiveChanged: {
        cursorX = -100000;
        if (!interactive) cancelDrag();
    }

    // ---------- model: one stable row per app ----------
    ListModel { id: rows }       // roles: key, removing

    Timer { id: purge; interval: 300; onTriggered: root.purgeLeaving() }
    Timer { id: leave; interval: 50; onTriggered: root.cursorX = -100000 }

    Connections {
        target: DockState
        function onItemsChanged() { root.sync(); }
    }

    Component.onCompleted: sync()

    function indexOfKey(k) {
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).key === k) return i;
        return -1;
    }

    function sync() {
        // an app opening or closing mid-drag would change the slots under the cursor
        if (dragKey !== "") cancelDrag();

        const list = Array.from(DockState.items);
        const keys = [];
        const nextSlots = {};
        let pinned = 0;
        for (let i = 0; i < list.length; i++) {
            keys.push(list[i].key);
            nextSlots[list[i].key] = i;
            if (list[i].pinned) pinned++;
        }
        // apps that are leaving keep their last slot so they fade out where they were
        for (const k of Object.keys(slots))
            if (nextSlots[k] === undefined && indexOfKey(k) !== -1) nextSlots[k] = slots[k];

        // slots first, so new delegates are born in the right place
        order = keys;
        slots = nextSlots;
        pinnedCount = pinned;

        let leaving = false;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            const alive = keys.indexOf(r.key) !== -1;
            if (!alive) {
                leaving = true;
                if (!r.removing) rows.setProperty(i, "removing", true);
            } else if (r.removing) {
                rows.setProperty(i, "removing", false);
            }
        }

        // live rows first, in order; leaving rows end up behind them
        for (let t = 0; t < keys.length; t++) {
            const idx = indexOfKey(keys[t]);
            if (idx < 0) rows.insert(t, { key: keys[t], removing: false });
            else if (idx !== t) rows.move(idx, t, 1);
        }

        if (leaving) purge.restart();
    }

    function purgeLeaving() {
        for (let i = rows.count - 1; i >= 0; i--)
            if (rows.get(i).removing) rows.remove(i);
        const pruned = {};
        for (const k of order) pruned[k] = slots[k];
        slots = pruned;
    }

    // ---------- drag ----------
    function beginDrag(key, startX) {
        const s = slots[key];
        if (s === undefined) return;
        dragFollow = true;
        dragX = startX;
        dragFrom = s;
        dragTo = s;
        dragKey = key;
    }

    function moveDrag(wantedX) {
        const last = Math.max(0, pinnedCount - 1);
        dragX = Math.max(0, Math.min(last * slotW, wantedX));
        dragTo = Math.max(0, Math.min(last, Math.round(dragX / slotW)));
    }

    function cancelDrag() {
        dragFollow = false;
        dragKey = "";
    }

    function endDrag() {
        if (dragKey === "") return;
        const from = dragFrom;
        const to = dragTo;
        const dragged = DockState.itemMap[order[from]];
        const target = DockState.itemMap[order[to]];

        // easing back on first, then let go: the dragged app glides into its slot
        dragFollow = false;
        dragKey = "";
        cursorX = -100000;

        if (from !== to && dragged && target && dragged.pinned && target.pinned)
            DockState.moveFavorite(dragged.id, target.id);
    }

    // ---------- items ----------
    Repeater {
        model: rows

        DockItem {
            id: tile

            required property string key
            required property bool removing

            readonly property var live: DockState.itemMap[key] ?? null
            readonly property bool dragging: root.dragKey === key
            readonly property int slot: root.slots[key] ?? 0
            // where this app sits right now, counting the gap opened by a drag in progress
            readonly property int visualSlot: {
                if (root.dragKey === "" || dragging || removing) return slot;
                const f = root.dragFrom;
                const t = root.dragTo;
                if (f < t && slot > f && slot <= t) return slot - 1;
                if (f > t && slot >= t && slot < f) return slot + 1;
                return slot;
            }

            // follows the live app, and just keeps the last one while it fades out
            item: root.blankItem
            Binding {
                target: tile
                property: "item"
                value: tile.live
                when: tile.live !== null
                restoreMode: Binding.RestoreNone
            }

            iconSize: root.iconSize
            hitPad: root.spacing / 2
            tipEnabled: root.tipsEnabled && root.dragKey === ""
            draggable: root.interactive && item.pinned && !removing
            lifted: dragging
            present: !removing

            zoom: {
                if (root.magnify <= 1 || !root.interactive || root.dragKey !== "" || removing)
                    return 1;
                const d = Math.abs(root.cursorX - (visualSlot * root.slotW + width / 2));
                if (d >= root.magnifyRadius) return 1;
                const t = 1 - d / root.magnifyRadius;
                return 1 + (root.magnify - 1) * t * t * (3 - 2 * t);
            }

            x: dragging ? root.dragX : visualSlot * root.slotW
            y: 0

            Behavior on x {
                enabled: !root.dragFollow
                NumberAnimation { duration: root.slideDuration; easing.type: Easing.OutCubic }
            }

            onHoverMoved: cx => {
                leave.stop();
                root.cursorX = cx;
            }
            onHoverLeft: leave.restart()

            onDragStarted: root.beginDrag(key, x)
            onDragMoved: wantedX => root.moveDrag(wantedX)
            onDragEnded: root.endDrag()

            onMenuRequested: root.menuRequested(item, mapToItem(null, width / 2, 0).x)
        }
    }
}
