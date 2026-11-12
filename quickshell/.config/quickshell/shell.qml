import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    
    Dock {}

    // Native notification daemon (replaces dunst).
    // DND is on only while a Pomodoro focus session is running.
    Notifications {
    topOffset: 8 
    dnd: PomodoroService.running && PomodoroService.phase === "focus"
}

    // Keybind option 1 (Hyprland global shortcut). In hyprland.conf:
    //   bind = SUPER, B, global, quickshell:toggleBarOrientation
    GlobalShortcut {
        name: "toggleBarOrientation"
        description: "Toggle the bar between horizontal (top) and vertical (left)"
        onPressed: BarState.toggle()
    }

    // Keybind option 2 (works from any compositor / terminal):
    //   qs ipc call bar toggle
    //   qs ipc call bar vertical
    //   qs ipc call bar horizontal
    IpcHandler {
        target: "bar"
        function toggle(): void     { BarState.toggle() }
        function vertical(): void   { BarState.setVertical() }
        function horizontal(): void { BarState.setHorizontal() }
    }
}
