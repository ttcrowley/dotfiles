pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    // Favorites are desktop entry ids, e.g. "firefox", "org.kde.dolphin"
    readonly property var favorites: store.favorites

    // Pinned apps first (in saved order), then running apps that aren't pinned.
    // Each item: { id, entry, name, icon, windows: [Toplevel], pinned }
    readonly property var items: buildItems(
        ToplevelManager.toplevels.values,
        store.favorites,
        DesktopEntries.applications.values
    )

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell/dock-favorites.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        adapter: JsonAdapter {
            id: store
            property list<string> favorites: []
        }
    }

    // ---------- helpers ----------

    function norm(s) {
        return (s ?? "").toString().toLowerCase().replace(/\.desktop$/, "");
    }

    function entryFor(id) {
        if (!id) return null;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) ?? null;
    }

    function buildItems(toplevels, favs, apps) {
        // group open windows by appId
        const groups = {};
        for (const t of Array.from(toplevels)) {
            const k = norm(t.appId);
            if (!groups[k]) groups[k] = [];
            groups[k].push(t);
        }

        const claimed = {};
        const out = [];

        for (const fav of Array.from(favs)) {
            const entry = entryFor(fav);
            if (!entry) continue;

            const keys = [fav, entry.id, entry.startupClass, entry.name]
                .map(norm)
                .filter(k => k !== "");

            let wins = [];
            for (const k of keys) {
                if (groups[k] && !claimed[k]) {
                    wins = wins.concat(groups[k]);
                    claimed[k] = true;
                }
            }
            out.push({ id: fav, entry: entry, name: entry.name, icon: entry.icon, windows: wins, pinned: true });
        }

        for (const k of Object.keys(groups)) {
            if (claimed[k]) continue;
            const wins = groups[k];
            const entry = entryFor(wins[0].appId);
            out.push({
                id: entry ? entry.id : "",
                entry: entry,
                name: entry ? entry.name : wins[0].appId,
                icon: entry ? entry.icon : wins[0].appId,
                windows: wins,
                pinned: false
            });
        }
        return out;
    }

    // ---------- actions ----------

    function pin(id) {
        const f = Array.from(store.favorites);
        if (!f.includes(id)) {
            f.push(id);
            store.favorites = f;
        }
    }

    function unpin(id) {
        store.favorites = Array.from(store.favorites).filter(f => f !== id);
    }

    function launch(item) {
        if (item.entry) item.entry.execute();
    }

    // Launch if closed, otherwise focus (cycles through windows if there are several)
    function activate(item) {
        const w = item.windows;
        if (w.length === 0) {
            launch(item);
            return;
        }
        const idx = w.findIndex(x => x.activated);
        w[(idx + 1) % w.length].activate();
    }

    function menuRows(item) {
        const rows = [];
        const n = item.windows.length;

        for (const w of item.windows)
            rows.push({ label: w.title || item.name, run: () => w.activate() });

        if (n > 0) rows.push({ sep: true });

        if (item.entry) {
            rows.push({ label: "New window", run: () => item.entry.execute() });
            for (const a of Array.from(item.entry.actions))
                rows.push({ label: a.name, run: () => a.execute() });
        }

        if (item.id)
            rows.push({
                label: item.pinned ? "Unpin from dock" : "Pin to dock",
                run: () => item.pinned ? unpin(item.id) : pin(item.id)
            });

        if (n > 0)
            rows.push({
                label: n > 1 ? "Close all windows" : "Close window",
                danger: true,
                run: () => item.windows.forEach(w => w.close())
            });

        return rows;
    }
}
