import QtQuick

// Little tomato drawn with plain shapes (no icon font needed).
Item {
    id: root
    property color body: "#E5533D"
    property color leaf: "#98C379"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    // Fruit
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.size * 0.92
        height: root.size * 0.80
        radius: height / 2
        color: root.body
    }

    // Calyx (leaves)
    Rectangle {
        x: root.width / 2 - width + root.size * 0.04
        y: root.size * 0.17
        width: root.size * 0.40
        height: root.size * 0.17
        radius: height / 2
        rotation: -25
        color: root.leaf
    }
    Rectangle {
        x: root.width / 2 - root.size * 0.04
        y: root.size * 0.17
        width: root.size * 0.40
        height: root.size * 0.17
        radius: height / 2
        rotation: 25
        color: root.leaf
    }

    // Stem
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: Math.max(2, root.size * 0.12)
        height: root.size * 0.24
        radius: width / 2
        color: root.leaf
    }
}
