import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: tile

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property bool showArrow: false
    property bool arrowChecked: false
    signal clicked()
    signal arrowClicked()

    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 2.6

    readonly property color fgColor: active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

    Rectangle {
        id: background
        anchors.fill: parent
        radius: height / 2
        opacity: tile.available ? 1 : 0.45
        color: tile.active
               ? (mainArea.containsMouse
                  ? Qt.lighter(Kirigami.Theme.highlightColor, 1.15)
                  : Kirigami.Theme.highlightColor)
               : Qt.rgba(Kirigami.Theme.textColor.r,
                         Kirigami.Theme.textColor.g,
                         Kirigami.Theme.textColor.b,
                         mainArea.containsMouse ? 0.2 : 0.12)

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: tile.showArrow ? 0 : Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing * 2
        opacity: tile.available ? 1 : 0.6

        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            source: tile.icon
            color: tile.fgColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            PC3.Label {
                Layout.fillWidth: true
                text: tile.title
                font.weight: Font.Medium
                elide: Text.ElideRight
                color: tile.fgColor
            }

            PC3.Label {
                Layout.fillWidth: true
                visible: tile.subtitle !== ""
                text: tile.subtitle
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                elide: Text.ElideRight
                color: tile.fgColor
            }
        }

        // Trennlinie + Pfeil (wie bei GNOME)
        Rectangle {
            visible: tile.showArrow
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing * 2
            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
            color: Qt.rgba(tile.fgColor.r, tile.fgColor.g, tile.fgColor.b, 0.3)
        }

        Item {
            visible: tile.showArrow
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: tile.arrowChecked ? "arrow-down-symbolic" : "arrow-right-symbolic"
                color: tile.fgColor
                opacity: arrowArea.containsMouse ? 1 : 0.7
            }

            MouseArea {
                id: arrowArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tile.arrowClicked()
            }
        }
    }

    MouseArea {
        id: mainArea
        anchors.fill: parent
        anchors.rightMargin: tile.showArrow ? Kirigami.Units.gridUnit * 1.8 : 0
        hoverEnabled: true
        enabled: tile.available
        onClicked: tile.clicked()
    }
}
