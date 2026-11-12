pragma Singleton
import Quickshell
import QtQuick

// Grayscale-only palette (R = G = B everywhere).
// Names are unchanged, so no other file needs to be touched.
Singleton {
    // Base palette
    readonly property color bg: "#0C0C0C"        // main background
    readonly property color surface: "#2C2C2C"   // dense shadow
    readonly property color border: "#4E4E4E"    // dark mid gray
    readonly property color dim: "#747474"       // neutral gray
    readonly property color muted: "#A4A4A4"     // light gray
    readonly property color fg: "#DFDFDF"        // near white
    readonly property color accent: "#FFFFFF"    // highlight (brightest value)

    // Alert red (the one color exception to the grayscale palette)
    readonly property color warn: "#F38BA8"

    // Network "connected"
    readonly property color connected: "#CFCFCF"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14

    // Muted accents (used sparingly)
    readonly property color green: "#8FB996"
    readonly property color red: "#C78A8E"
    readonly property color yellow: "#C2B67E"
    readonly property color cyan: "#7FB8BF"

    }
