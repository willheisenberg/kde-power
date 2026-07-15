import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Power-Menü"
    toolTipSubText: "Energie, Netzwerk und Schnelleinstellungen"

    // Eigene Kompaktdarstellung, damit das Icon dieselbe Größe hat
    // wie die übrigen Symbole im Systemabschnitt
    compactRepresentation: MouseArea {
        id: compact

        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.centerIn: parent
            // iconSizes.small entspricht der Größe der Symbole im Systemabschnitt
            width: Math.min(Math.min(compact.width, compact.height),
                            Kirigami.Units.iconSizes.small)
            height: width
            source: "system-shutdown-symbolic"
            active: compact.containsMouse
        }
    }

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }
}
