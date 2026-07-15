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
    property bool showSwitch: false
    property bool switchOn: false
    signal clicked()

    // Optimistische Anzeige: Beim Klick schiebt der Schalter sofort um.
    // Bestätigt der echte Zustand (switchOn) das Ziel, wird er übernommen;
    // bleibt die Bestätigung aus (z. B. Verbinden fehlgeschlagen), gleitet
    // der Schalter nach Ablauf des Timers animiert zurück.
    property int _pendingTarget: -1
    readonly property bool effectiveOn: _pendingTarget >= 0 ? _pendingTarget === 1 : switchOn

    onSwitchOnChanged: {
        if (_pendingTarget >= 0 && switchOn === (_pendingTarget === 1)) {
            _pendingTarget = -1
            pendingTimer.stop()
        }
    }

    Timer {
        id: pendingTimer
        interval: 10000
        onTriggered: item._pendingTarget = -1
    }

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

        // Schalter im GNOME-Stil
        Rectangle {
            visible: item.showSwitch
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.gridUnit * 2.2
            implicitHeight: Kirigami.Units.gridUnit * 1.2
            radius: height / 2
            color: item.effectiveOn
                   ? Kirigami.Theme.highlightColor
                   : Qt.rgba(Kirigami.Theme.textColor.r,
                             Kirigami.Theme.textColor.g,
                             Kirigami.Theme.textColor.b, 0.3)

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.longDuration }
            }

            Rectangle {
                width: parent.height - Kirigami.Units.smallSpacing
                height: width
                radius: width / 2
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: item.effectiveOn
                   ? parent.width - width - Kirigami.Units.smallSpacing / 2
                   : Kirigami.Units.smallSpacing / 2

                Behavior on x {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (item.showSwitch) {
                item._pendingTarget = item.switchOn ? 0 : 1
                pendingTimer.restart()
            }
            item.clicked()
        }
    }
}
