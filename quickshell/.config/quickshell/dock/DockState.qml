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

    // key -> item, so the dock can keep one stable delegate per app
    readonly property var itemMap: buildMap(items)

    function buildMap(list) {
        const m = {};
        for (const it of Array.from(list)) m[it.key] = it;
        return m;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell/dock/dock-favorites.json"
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

    // ---------- installed-app check ----------
    // DesktopEntries can keep serving entries whose .desktop file is gone, so we also
    // list the .desktop files that really exist and filter against that list.
    property var installed: ({})
    property bool installedReady: false

    function isInstalled(entry) {
        return !installedReady || installed[entry.id] === true;
    }

    function refreshInstalled() {
        if (!scan.running) scan.running = true;
    }

    Process {
        id: scan
        running: true
        command: ["sh", "-c",
            "dirs=\"${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            + ":/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
            + ":/var/lib/snapd/desktop\"; "
            + "IFS=:; for d in $dirs; do "
            + "[ -d \"$d/applications\" ] && find -L \"$d/applications\" -name '*.desktop' -printf '%P\\n'; "
            + "done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const set = {};
                for (const line of text.split("\n")) {
                    const l = line.trim();
                    if (l === "") continue;
                    set[l.replace(/\.desktop$/, "").replace(/\//g, "-")] = true;
                }
                root.installed = set;
                root.installedReady = Object.keys(set).length > 0;
            }
        }
    }

    // ---------- helpers ----------

    function norm(s) {
        return (s ?? "").toString().toLowerCase().replace(/\.desktop$/, "");
    }

    function squash(s) {
        return (s ?? "").toString().toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function iconBase(e) {
        return (e.icon ?? "").toString().split("/").pop().replace(/\.[a-z]+$/i, "");
    }

    // Steam games open a window whose appId is "steam_app_<number>", which matches no
    // .desktop file. The numbers a launcher entry can be known by:
    //  - the id in "steam steam://rungameid/<id>", or in the icon "steam_icon_<id>"
    //  - for non-Steam shortcuts (a huge 64-bit id) the 32-bit app id inside it,
    //    which is the one Steam puts in the window's class
    function steamIdsOfEntry(e) {
        const ids = [];
        const exec = (e.execString ?? "").toString();
        const icon = (e.icon ?? "").toString();
        const m = /rungameid\/(\d+)/.exec(exec) ?? /steam_icon_(\d+)/.exec(icon);
        if (!m) return ids;
        ids.push(m[1]);
        const n = Number(m[1]);
        if (n >= 4294967296) ids.push(String(Math.floor(n / 4294967296)));
        return ids;
    }

    function steamEntry(appId) {
        const m = /^steam_app_(\d+)$/.exec((appId ?? "").toString().toLowerCase());
        if (!m) return null;
        for (const e of Array.from(DesktopEntries.applications.values))
            if (steamIdsOfEntry(e).indexOf(m[1]) !== -1) return e;
        return null;
    }

    // last resort: the window's appId is the app's name or icon name with the spaces
    // squeezed out ("SlayTheSpire2" for "Slay the Spire 2")
    function nameEntry(appId) {
        const q = squash(appId);
        if (q === "") return null;
        for (const e of Array.from(DesktopEntries.applications.values))
            if (squash(e.name) === q || squash(e.id) === q || squash(iconBase(e)) === q) return e;
        return null;
    }

    function entryFor(id) {
        if (!id) return null;
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
                  ?? steamEntry(id) ?? nameEntry(id) ?? null;
        return (e && isInstalled(e)) ? e : null;
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

            const keys = [fav, entry.id, entry.startupClass, entry.name, iconBase(entry)]
                .concat(steamIdsOfEntry(entry).map(i => "steam_app_" + i))
                .map(norm)
                .filter(k => k !== "");

            let wins = [];
            for (const k of keys) {
                if (groups[k] && !claimed[k]) {
                    wins = wins.concat(groups[k]);
                    claimed[k] = true;
                }
            }
            out.push({ key: "p:" + norm(fav), id: fav, entry: entry, name: entry.name, icon: entry.icon, windows: wins, pinned: true });
        }

        for (const k of Object.keys(groups)) {
            if (claimed[k]) continue;
            const wins = groups[k];
            const entry = entryFor(wins[0].appId);
            out.push({
                key: "r:" + k,
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

    // Drag-and-drop reorder: put `id` where `targetId` currently is.
    function moveFavorite(id, targetId) {
        const f = Array.from(store.favorites);
        const from = f.indexOf(id);
        const to = f.indexOf(targetId);
        if (from < 0 || to < 0 || from === to) return;
        f.splice(from, 1);
        f.splice(to, 0, id);
        store.favorites = f;
    }

    function unpin(id) {
        store.favorites = Array.from(store.favorites).filter(f => f !== id);
    }

    // Launcher search: prefix matches first, then word matches, then substring,
    // then genericName / comment / keywords. Pinned apps win ties.
    function search(query) {
        const q = (query ?? "").trim().toLowerCase();
        const favs = Array.from(store.favorites);
        const scored = [];

        for (const e of Array.from(DesktopEntries.applications.values)) {
            if (e.noDisplay || !isInstalled(e)) continue;
            const name = e.name.toLowerCase();
            let s = -1;
            if (q === "") s = 0;
            else if (name.startsWith(q)) s = 0;
            else if (name.includes(" " + q) || name.includes("-" + q)) s = 1;
            else if (name.includes(q)) s = 2;
            else if ((e.genericName ?? "").toLowerCase().includes(q)
                  || (e.comment ?? "").toLowerCase().includes(q)
                  || Array.from(e.keywords ?? []).some(k => k.toLowerCase().includes(q))) s = 3;
            if (s < 0) continue;
            scored.push({ e: e, s: s, p: favs.indexOf(e.id) !== -1 ? 1 : 0 });
        }

        scored.sort((a, b) => (a.s - b.s) || (b.p - a.p) || a.e.name.localeCompare(b.e.name));
        return scored.map(x => x.e);
    }

    // Middle click: close one window of the app (the focused one, else the last).
    // Click again to close the next. Does nothing if the app isn't running.
    function closeWindow(item) {
        const w = item.windows;
        if (w.length === 0) return;
        const target = w.find(x => x.activated) ?? w[w.length - 1];
        target.close();
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
