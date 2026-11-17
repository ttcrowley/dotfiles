pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Grayscale dark palette plus a warm cream-paper light variant.
// Every widget reads Theme.bg / Theme.fg / ..., so flipping `dark` restyles the whole
// shell (bar and dock) and the colors cross-fade.
// The choice is saved to ~/.local/state/quickshell-theme (honours $XDG_STATE_HOME).
// Bar and dock are separate Quickshell instances, so they stay in sync by watching
// that file: change it in either one and the other follows.
Singleton {
    id: root

    // ── Mode ────────────────────────────────────────────────
    property bool dark: true

    function setDark(v: bool): void {
        dark = v
        file.setText(v ? "dark" : "light")
        applyApps(v)
    }
    function toggle(): void { setDark(!dark) }

    // theme-apply restyles kitty, Yazi and GTK3 and runs the wallpaper switcher.
    // Only the instance where the switch happens runs it; the other instance just follows
    // the state file. (Script: ~/.local/bin/theme-apply)
    readonly property string applyScript: Quickshell.env("HOME") + "/.local/bin/theme-apply"
    function applyApps(v: bool): void {
        Quickshell.execDetached([applyScript, v ? "dark" : "light"])
    }

    readonly property string stateFile:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/quickshell-theme"

    // True after the first load: at startup the apps and wallpaper are re-synced once
    // to the saved mode, later reloads (the other instance toggling) do not re-run it.
    property bool booted: false

    FileView {
        id: file
        path: root.stateFile
        blockLoading: true      // read before the first frame, so there is no flash
        watchChanges: true      // the other instance picks up a change made here
        onFileChanged: reload()
        // Assign directly (not via setDark()) so loading never rewrites the file.
        // No file yet (first run): stays dark.
        onLoaded: {
            root.dark = file.text().trim() !== "light"
            if (!root.booted) {
                root.booted = true
                root.applyApps(root.dark)
            }
        }
        onSaveFailed: err => console.warn("Theme: could not save mode:", err)
    }

    // ── Base palette (dark is pure gray; light carries a faint warm tint) ──
    // Roles stay the same in both modes: bg is the base, surface sits one step above it,
    // fg/accent are the text colors, and accent is the strongest contrast.
    property color bg:      dark ? "#0C0C0C" : "#E9E9E9"   // main background
    property color surface: dark ? "#2C2C2C" : "#D6D6D6"   // raised panels / hover fills
    property color border:  dark ? "#4E4E4E" : "#B5B5B5"   // lines and inactive dots
    property color dim:     dark ? "#747474" : "#6B6B6B"   // quiet text and icons
    property color muted:   dark ? "#A4A4A4" : "#555555"   // secondary text
    property color fg:      dark ? "#DFDFDF" : "#1C1C1C"   // main text
    property color accent:  dark ? "#FFFFFF" : "#0F0F0F"   // highlight (strongest contrast)

    // Alert red (the one color exception to the grayscale palette)
    property color warn:    dark ? "#F38BA8" : "#A02F6F"

    // Network "connected"
    property color connected: dark ? "#CFCFCF" : "#403E3C"

    // Muted accents (used sparingly)
    property color green:   dark ? "#8FB996" : "#66800B"
    property color red:     dark ? "#C78A8E" : "#AF3029"
    property color yellow:  dark ? "#C2B67E" : "#8E6B01"
    property color cyan:    dark ? "#7FB8BF" : "#24837B"

    // Cross-fade when the mode flips
    Behavior on bg        { ColorAnimation { duration: root.animMed } }
    Behavior on surface   { ColorAnimation { duration: root.animMed } }
    Behavior on border    { ColorAnimation { duration: root.animMed } }
    Behavior on dim       { ColorAnimation { duration: root.animMed } }
    Behavior on muted     { ColorAnimation { duration: root.animMed } }
    Behavior on fg        { ColorAnimation { duration: root.animMed } }
    Behavior on accent    { ColorAnimation { duration: root.animMed } }
    Behavior on warn      { ColorAnimation { duration: root.animMed } }
    Behavior on connected { ColorAnimation { duration: root.animMed } }
    Behavior on green     { ColorAnimation { duration: root.animMed } }
    Behavior on red       { ColorAnimation { duration: root.animMed } }
    Behavior on yellow    { ColorAnimation { duration: root.animMed } }
    Behavior on cyan      { ColorAnimation { duration: root.animMed } }

    // ── Type ────────────────────────────────────────────────
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14

    // Shared shape / motion / locale tokens
    readonly property int radius: 12        // panels and popups
    readonly property int radiusSmall: 6    // tooltips, menu rows, small buttons
    readonly property int animFast: 150     // hover and color transitions
    readonly property int animMed: 220      // slides, growth, workspace motion
    readonly property var locale: Qt.locale("pt_BR")
}
