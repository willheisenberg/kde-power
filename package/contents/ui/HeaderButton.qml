import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: btn

    property string icon: ""
    property bool checked: false
    property string tooltip: ""
    signal clicked()

    implicitWidth: Kirigami.Units.gridUnit * 2.2
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.checked
               ? Kirigami.Theme.highlightColor
               : Qt.rgba(Kirigami.Theme.textColor.r,
                         Kirigami.Theme.textColor.g,
                         Kirigami.Theme.textColor.b,
                         mouseArea.containsMouse ? 0.25 : 0.12)

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        source: btn.icon
        color: btn.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }

    PC3.ToolTip {
        text: btn.tooltip
        visible: mouseArea.containsMouse && btn.tooltip !== ""
    }
}
