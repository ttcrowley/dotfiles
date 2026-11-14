import Quickshell

// Standalone dock instance. Run with:  qs -p ~/.config/quickshell/dock
ShellRoot {
    Dock { onClipboardRequested: clipboard.toggle() }

    // cliphist history menu (opened from the dock's utils state)
    ClipboardMenu { id: clipboard }
}
