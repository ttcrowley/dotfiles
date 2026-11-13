import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes

// Workspace dots joined by curved "necks" (liquid / metaball look).
// The focused dot swells, and the swell travels smoothly between workspaces.
// Works in both bar orientations (BarState.vertical).
Item {
    id: root
    readonly property bool vertical: BarState.vertical

    // ── Tuning ──────────────────────────────────────────────
    readonly property real slot: 20      // distance between dot centers
    readonly property real rSmall: 4     // 8px dots, same as before
    readonly property real rBig: 6.5     // focused dot radius
    readonly property real neck: 1.2     // smaller = thinner waist between dots
    readonly property real sinA: 0.8     // where necks meet the circles (~55 deg)
    readonly property real cosA: 0.6
    readonly property int animMs: 220

    // ── State ───────────────────────────────────────────────
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? -1
    readonly property var occupiedIds: Hyprland.workspaces.values.map(w => w.id)

    // ── Alerts ──────────────────────────────────────────────
    // Workspaces that want attention: { wsId: true }. Cleared when you visit them.
    property var alerts: ({})
    readonly property color alertColor: Theme.warn   // try Theme.yellow for something softer
    readonly property int pulseMs: 1100

	function alert(ws) {
	    if (isNaN(ws) || ws === focusedId || alerts[ws] === true)
		return;
	    alerts = Object.assign({}, alerts, { [ws]: true });
	}

	function clearAlert(ws) {
	    if (alerts[ws] !== true)
		return;
	    const next = Object.assign({}, alerts);
	    delete next[ws];
	    alerts = next;
	}

	onFocusedIdChanged: clearAlert(focusedId)

	Connections {
	    target: Hyprland

	    function onRawEvent(event) {
		// console.log("hypr:", event.name, event.data);   // uncomment to debug

		// A window opened (e.g. Obsidian on another workspace).
		// data = "address,workspaceName,class,title"
		if (event.name === "openwindow") {
		    root.alert(parseInt(event.data.split(",")[1]));
		}
		// A window asked for attention (e.g. a paused game wanting focus).
		// data = window address
		else if (event.name === "urgent") {
		    const addr = event.data.trim().replace(/^0x/, "");
		    const t = Hyprland.toplevels.values.find(
			t => t.address.replace(/^0x/, "") === addr);
		    if (t && t.workspace)
			root.alert(t.workspace.id);
		}
	    }
	}


    // Same visibility rule as before: 1-4 always, others if focused/occupied
    readonly property var shown: {
        const ids = [];
        for (let i = 1; i <= 9; i++)
            if (i <= 4 || i === focusedId || occupiedIds.includes(i))
                ids.push(i);
        return ids;
    }
    readonly property int count: shown.length
    readonly property int focusedIdx: shown.indexOf(focusedId)

    // Animated (fractional) index of the focused dot
    property real pos: focusedIdx >= 0 ? focusedIdx : 0
    onFocusedIdxChanged: if (focusedIdx >= 0) pos = focusedIdx
    Behavior on pos { NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }

    // 0 when the focused workspace isn't in the list (e.g. special workspace)
    property real swell: focusedIdx >= 0 ? 1 : 0
    Behavior on swell { NumberAnimation { duration: root.animMs } }

    // Radius of dot i: grows the closer the animated position is to it
    function rad(i) {
        return rSmall + (rBig - rSmall) * swell * Math.max(0, 1 - Math.abs(i - pos));
    }

    // Axis helpers: a = along the bar, c = across it
    function px(a, c) { return vertical ? c : a; }
    function py(a, c) { return vertical ? a : c; }

    readonly property real cross: rBig * 2 + 4
    implicitWidth: vertical ? cross : count * slot
    implicitHeight: vertical ? count * slot : cross

    // ── Necks between neighbouring dots ─────────────────────
    Repeater {
        model: Math.max(0, root.count - 1)

        delegate: Shape {
            id: seg
            required property int index
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer   // Qt 6.6+; delete this line if it errors

            readonly property real mid: root.cross / 2
            readonly property real a1: root.slot * (index + 0.5)
            readonly property real a2: a1 + root.slot
            readonly property real am: (a1 + a2) / 2
            readonly property real r1: root.rad(index)
            readonly property real r2: root.rad(index + 1)

            ShapePath {
                fillColor: Theme.border
                strokeColor: "transparent"

                startX: root.px(seg.a1 + root.cosA * seg.r1, seg.mid - root.sinA * seg.r1)
                startY: root.py(seg.a1 + root.cosA * seg.r1, seg.mid - root.sinA * seg.r1)

                PathQuad {
                    x: root.px(seg.a2 - root.cosA * seg.r2, seg.mid - root.sinA * seg.r2)
                    y: root.py(seg.a2 - root.cosA * seg.r2, seg.mid - root.sinA * seg.r2)
                    controlX: root.px(seg.am, seg.mid - root.neck)
                    controlY: root.py(seg.am, seg.mid - root.neck)
                }
                PathLine {
                    x: root.px(seg.a2 - root.cosA * seg.r2, seg.mid + root.sinA * seg.r2)
                    y: root.py(seg.a2 - root.cosA * seg.r2, seg.mid + root.sinA * seg.r2)
                }
                PathQuad {
                    x: root.px(seg.a1 + root.cosA * seg.r1, seg.mid + root.sinA * seg.r1)
                    y: root.py(seg.a1 + root.cosA * seg.r1, seg.mid + root.sinA * seg.r1)
                    controlX: root.px(seg.am, seg.mid + root.neck)
                    controlY: root.py(seg.am, seg.mid + root.neck)
                }
            }
        }
    }

    // ── Dots ────────────────────────────────────────────────
    Repeater {
        model: root.count

        delegate: Rectangle {
            id: dot
            required property int index
            readonly property int wsId: root.shown[index]
            readonly property bool focused: wsId === root.focusedId
            readonly property bool occupied: root.occupiedIds.includes(wsId)
            readonly property real r: root.rad(index)

            width: r * 2
            height: width
            radius: r
            x: root.px(root.slot * (index + 0.5), root.cross / 2) - width / 2
            y: root.py(root.slot * (index + 0.5), root.cross / 2) - height / 2

           readonly property bool alerted: root.alerts[wsId] === true && !focused
	property real pulse: 0

	color: alerted ? root.alertColor
	     : focused ? Theme.accent
	     : occupied ? Theme.muted
	     : Theme.border
	Behavior on color { ColorAnimation { duration: 150 } }

	NumberAnimation on pulse {
	    from: 0
	    to: 1
	    duration: root.pulseMs
	    loops: Animation.Infinite
	    running: dot.alerted
	}

// Expanding, fading ring
Rectangle {
    visible: dot.alerted
    anchors.centerIn: parent
    width: dot.width + 12 * dot.pulse
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1.5
    border.color: root.alertColor
    opacity: 1 - dot.pulse
}        }
    }

    // ── Click targets ───────────────────────────────────────
    Repeater {
        model: root.count

        delegate: MouseArea {
            required property int index
            x: root.vertical ? 0 : root.slot * index
            y: root.vertical ? root.slot * index : 0
            width: root.vertical ? root.cross : root.slot
            height: root.vertical ? root.slot : root.cross
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached([
                "hyprctl", "dispatch",
                'hl.dsp.focus({ workspace = "' + root.shown[index] + '" })'
            ])
        }
    }

    WheelHandler {
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? "-1" : "+1"
            Quickshell.execDetached([
                "hyprctl", "dispatch",
                'hl.dsp.focus({ workspace = "' + dir + '" })'
            ])
        }
    }
}
