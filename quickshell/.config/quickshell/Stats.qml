import Quickshell
import Quickshell.Io
import QtQuick

Grid {
    id: root
    flow: Grid.LeftToRight
    columns: BarState.vertical ? 1 : 3
    spacing: BarState.vertical ? 10 : 12
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    property int cpu: 0
    property int mem: 0
    property int temp: 0
    property var prev: null

    Process {
        id: proc
        command: ["sh", "-c", `
            head -n1 /proc/stat
            awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d\\n",(t-a)*100/t}' /proc/meminfo
            t=0
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat $h/name)" in k10temp|coretemp) t=$(cat $h/temp1_input); break;; esac
            done
            echo $t
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")

                const p = lines[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = p[3] + p[4]
                const total = p.reduce((a, b) => a + b, 0)
                if (root.prev) {
                    const dt = total - root.prev.total
                    const di = idle - root.prev.idle
                    if (dt > 0) root.cpu = Math.round(100 * (1 - di / dt))
                }
                root.prev = { idle: idle, total: total }

                root.mem = parseInt(lines[1])
                root.temp = Math.round(parseInt(lines[2]) / 1000)
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Gauge { label: "CPU";  icon: "\uf2db"; value: root.cpu }
    Gauge { label: "RAM";  icon: "\uf1c0"; value: root.mem }
    Gauge {
        label: "Temp"; icon: "\uf2c9"; unit: "°C"
        value: root.temp
        fillColor: root.temp >= 80 ? Theme.warn : Theme.accent
    }
}
