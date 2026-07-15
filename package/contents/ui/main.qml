import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Power-Menü"
    toolTipSubText: "Energie, Netzwerk und Schnelleinstellungen"

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }
}
