pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Pomodoro timer + focus music.
// Lives as a singleton so the timer keeps running while the popup is closed
// (and is shared between monitors).
Singleton {
    id: root

    // ── Settings (edit freely) ──────────────────────────────
    property int focusMin: 25
    property int shortBreakMin: 5
    property int longBreakMin: 15
    property int cyclesBeforeLong: 4
    property bool autoStartNext: true   // false = stop after each phase ends
    property bool musicOn: true         // play the link during focus
    property int musicVolume: 60        // 0-100, mpv's own volume (on top of system volume)


    // ── Tasks ───────────────────────────────────────────────
    // [{ text: "...", target: 3, count: 0 }]  — done when count >= target
    property var tasks: []
    property int pickedTask: -1   // task the user clicked as current (-1 = automatic)

    // Picked task if it's still open, otherwise the first unfinished one (-1 if none)
    readonly property int currentTask: {
        const p = pickedTask
        if (p >= 0 && p < tasks.length && tasks[p].count < tasks[p].target) return p
        return tasks.findIndex(t => t.count < t.target)
    }
    readonly property int tasksDone: tasks.filter(t => t.count >= t.target).length

    readonly property string tasksPath:
        (Quickshell.env("XDG_STATE_HOME") ?? (Quickshell.env("HOME") + "/.local/state"))
        + "/quickshell-pomodoro-tasks.json"

    function saveTasks() { taskFile.setText(JSON.stringify(tasks)) }

    function addTask(text, target) {
        const t = (text ?? "").trim()
        if (t === "") return
        tasks = tasks.concat([{ text: t, target: Math.max(1, target ?? 1), count: 0 }])
        saveTasks()
    }

    function pickTask(i) { pickedTask = i }

    function updateTask(i, text, target) {
        const s = (text ?? "").trim()
        if (s === "" || i < 0 || i >= tasks.length) return
        const t = tasks.slice()
        t[i] = { text: s, target: Math.max(1, Math.round(target)), count: t[i].count }
        tasks = t
        saveTasks()
    }

    // Checkbox: finish the task now, or reset it if it was already finished
    function toggleTask(i) {
        const t = tasks.slice()
        const x = t[i]
        t[i] = { text: x.text, target: x.target, count: x.count >= x.target ? 0 : x.target }
        tasks = t
        saveTasks()
    }

    function removeTask(i) {
        const t = tasks.slice()
        t.splice(i, 1)
        pickedTask = -1
        tasks = t
        saveTasks()
    }

    function clearDoneTasks() {
        pickedTask = -1
        tasks = tasks.filter(t => t.count < t.target)
        saveTasks()
    }

    // A finished focus session counts toward the current task; reaching its
    // target checks it, and the next unfinished task becomes current.
    function completeCurrentTask() {
        const i = currentTask
        if (i < 0) return
        const t = tasks.slice()
        t[i] = { text: t[i].text, target: t[i].target, count: t[i].count + 1 }
        tasks = t
        saveTasks()
    }

    FileView {
        id: taskFile
        path: root.tasksPath
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (Array.isArray(d))
                    root.tasks = d.map(t => ({
                        text: t.text,
                        target: t.target ?? 1,
                        count: t.count ?? (t.done ? 1 : 0)
                    }))
            } catch (e) {}
        }
    }


    // ── Timer state ─────────────────────────────────────────
    property string phase: "focus"      // "focus" | "short" | "long"
    property bool running: false
    property int remaining: 25 * 60     // seconds
    property int completed: 0           // finished focus sessions
    property double endAt: 0            // ms timestamp, avoids timer drift

    readonly property string timeText: fmt(remaining)
    readonly property real progress: 1 - remaining / phaseSeconds(phase)
    readonly property int cycleDots: phase === "long" ? cyclesBeforeLong
                                                      : completed % cyclesBeforeLong

    // ── Music state ─────────────────────────────────────────
    property string link: ""
    property string linkError: ""
    property string musicError: ""
    property bool stopping: false        // we asked mpv to quit
    property bool restartPending: false  // start mpv again once it exits

    readonly property string sock: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/qs-pomodoro-mpv.sock"
    readonly property bool wantPlaying: running && phase === "focus" && musicOn && link !== ""
    readonly property bool playing: wantPlaying && player.running && !stopping

    onWantPlayingChanged: syncMusic()

    // ── Helpers ─────────────────────────────────────────────
    function fmt(s) {
        const m = Math.floor(s / 60), r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    function phaseSeconds(p) {
        return (p === "focus" ? focusMin : p === "short" ? shortBreakMin : longBreakMin) * 60
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Pomodoro", title, body])
    }

    // Change a phase length (minutes). If that phase is the current one and
    // hasn't been started yet, the countdown updates right away; otherwise the
    // new length applies the next time that phase begins.
    function setDuration(which, min, step = 1) {
    const old = phaseSeconds(which)
    const cap = which === "focus" ? 120 : 60
    const m = Math.max(step, Math.min(cap, Math.round(min / step) * step))
    if (which === "focus")      focusMin = m
    else if (which === "short") shortBreakMin = m
    else                        longBreakMin = m
    if (!running && phase === which && remaining === old)
        remaining = phaseSeconds(which)
}

    // ── Timer control ───────────────────────────────────────
    function start() {
        if (remaining <= 0) remaining = phaseSeconds(phase)
        endAt = Date.now() + remaining * 1000
        running = true
    }

    function pause() {
        remaining = Math.max(0, Math.ceil((endAt - Date.now()) / 1000))
        running = false
    }

    function toggle() { running ? pause() : start() }

    function reset() {
        running = false
        phase = "focus"
        completed = 0
        remaining = phaseSeconds("focus")
        stopPlayer()
    }

    // Skip to the next phase without counting it as a finished session
    function skip() { advance(false) }

    function tick() {
        if (!running) return
        const ms = endAt - Date.now()
        if (ms <= 0) advance(true)
        else remaining = Math.ceil(ms / 1000)
    }

    function advance(finished) {
        const wasFocus = phase === "focus"
        if (wasFocus && finished) { completed++; completeCurrentTask() }
        phase = wasFocus
            ? (finished && completed % cyclesBeforeLong === 0 ? "long" : "short")
            : "focus"
        remaining = phaseSeconds(phase)

        if (finished) {
            if (phase === "focus")      notify("Break over", "Back to focus — " + focusMin + " min")
            else if (phase === "long")  notify("Focus complete", "Long break — " + longBreakMin + " min")
            else                        notify("Focus complete", "Short break — " + shortBreakMin + " min")
            if (!autoStartNext) running = false
        }
        if (running) endAt = Date.now() + remaining * 1000
    }

    Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }

    // ── Music ───────────────────────────────────────────────
    function submitLink(raw) {
        const u = (raw ?? "").trim()
        if (u === "") { linkError = "Clipboard is empty"; return false }
        if (!/^https?:\/\/(www\.|m\.|music\.)?(youtube\.com|youtu\.be)\//.test(u)) {
            linkError = "Not a YouTube link"
            return false
        }
        linkError = ""
        musicError = ""
        if (u === link) return true

        link = u
        if (player.running) {
            // Restart with the new link (onExited picks it up)
            restartPending = true
            stopping = true
            player.running = false
        } else if (wantPlaying) {
            startPlayer()
        }
        return true
    }

    function clearLink() {
        link = ""
        linkError = ""
        musicError = ""
        stopPlayer()
    }

    function paste() { pasteProc.running = true }

    function setVolume(v) {
        musicVolume = Math.max(0, Math.min(100, Math.round(v)))
        if (!volTimer.running) volTimer.start()   // throttle: don't spawn socat on every pixel
    }

   function startPlayer() {
   	if (player.running || link === "") return
    	musicError = ""
    	player.command = [
        	"mpv", "--no-video", "--no-terminal", "--force-window=no",
        	"--loop-playlist=inf", "--ytdl-format=bestaudio/best",
        	"--ytdl-raw-options=cookies-from-browser=firefox:/home/crowley/.var/app/app.zen_browser.zen/.zen/b1g5cmer.Default (release)",
        	"--volume=" + musicVolume,
        	"--input-ipc-server=" + sock, "--", link
    			]
    		player.running = true
	}

    function stopPlayer() {
        restartPending = false
        if (player.running) {
            stopping = true
            player.running = false
        }
    }

    function mpvSet(prop, value) {
        const msg = JSON.stringify({ command: ["set_property", prop, value] })
        Quickshell.execDetached([
            "sh", "-c", "printf '%s\\n' \"$1\" | socat - \"$2\"", "sh", msg, sock
        ])
    }

    function syncMusic() {
        if (wantPlaying) {
            if (stopping)            restartPending = true
            else if (player.running) mpvSet("pause", false)
            else                     startPlayer()
        } else if (player.running && !stopping) {
            mpvSet("pause", true)
        }
    }

    Timer {
        id: volTimer
        interval: 100
        onTriggered: if (player.running && !root.stopping) root.mpvSet("volume", root.musicVolume)
    }

    Process {
        id: player
        onExited: (code, status) => {
            const intentional = root.stopping
            root.stopping = false
            if (!intentional && code !== 0)
                root.musicError = "mpv failed — is yt-dlp installed?"
            if (root.restartPending) {
                root.restartPending = false
                if (root.wantPlaying) root.startPlayer()
            }
        }
    }

    Process {
        id: pasteProc
        command: ["wl-paste", "-n"]
        stdout: StdioCollector {
            onStreamFinished: root.submitLink(this.text)
        }
    }
}
