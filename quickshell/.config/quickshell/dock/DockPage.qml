import QtQuick

// One "state" of the dock. Pages sit stacked in the same spot; the current one
// is visible, the others are faded out and offset up or down by their distance
// from the current mode, so changing mode reads as a vertical slide.
Item {
    id: page

    property int index: 0
    property int mode: 0
    property int slide: 14
    readonly property bool current: index === mode
    // position relative to the current page on a 3-state loop: -1 above, 0 current, +1 below
    readonly property int rel: ((index - mode + 4) % 3) - 1

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    height: parent ? parent.height : 0
    y: rel * slide
    opacity: current ? 1 : 0
    // stay visible while fading out; also visible the moment it becomes current
    // so a TextField inside can take focus right away
    visible: current || opacity > 0.01
    enabled: current

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
}
