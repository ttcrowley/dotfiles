import QtQuick

Item {
    property int iconSize: 40

    width: 9
    height: iconSize + 20

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6 + iconSize * 0.2
        width: 1
        height: iconSize * 0.6
        color: Theme.border
    }
}
