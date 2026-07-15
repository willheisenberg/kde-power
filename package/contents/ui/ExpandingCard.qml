import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Karte, die sich mit Animation nach unten ausfährt.
// Kinder landen in einer inneren ColumnLayout.
Rectangle {
    id: card

    property bool open: false
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    clip: true
    radius: Kirigami.Units.largeSpacing
    color: Qt.rgba(Kirigami.Theme.textColor.r,
                   Kirigami.Theme.textColor.g,
                   Kirigami.Theme.textColor.b, 0.06)

    visible: open || height > 0
    implicitHeight: open ? contentColumn.implicitHeight + Kirigami.Units.largeSpacing * 2 : 0
    opacity: open ? 1 : 0

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration }
    }

    ColumnLayout {
        id: contentColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
    }
}
