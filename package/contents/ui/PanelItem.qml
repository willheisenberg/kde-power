import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: item

    property string icon: ""
    property string fallbackIcon: ""
    property string text: ""
    property string trailing: ""
    property bool bold: false
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing * 2

        Kirigami.Icon {
            visible: item.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            source: item.icon
            fallback: item.fallbackIcon
            color: Kirigami.Theme.textColor
        }

        PC3.Label {
            Layout.fillWidth: true
            text: item.text
            font.weight: item.bold ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        PC3.Label {
            visible: item.trailing !== ""
            text: item.trailing
            opacity: 0.7
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.clicked()
    }
}
