import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: item

    property string text: ""
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 1.9

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing * 1.5
        color: mouseArea.containsMouse
               ? Qt.rgba(Kirigami.Theme.textColor.r,
                         Kirigami.Theme.textColor.g,
                         Kirigami.Theme.textColor.b, 0.15)
               : "transparent"
    }

    PC3.Label {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Kirigami.Units.largeSpacing
        text: item.text
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.clicked()
    }
}
