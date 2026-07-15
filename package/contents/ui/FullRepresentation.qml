import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

Item {
    id: fullRoot

    property Item plasmoidItem: null

    // ---- Systemzustand ----
    property int batteryPercent: -1
    property int batteryState: 0            // UPower: 1=lädt, 2=entlädt, 4=voll
    property string batteryIcon: "battery-full-symbolic"
    property var displayIds: []      // z. B. ["display0", "display1"]
    property var displayInfo: ({})   // id -> { brightness, max, label }
    property bool wifiOn: false
    property string wifiSsid: ""
    property bool btOn: false
    property string powerProfile: ""        // leer = power-profiles-daemon fehlt
    property bool nightOn: false
    property string colorScheme: ""
    property int kbdBrightness: -1
    property int kbdMax: -1
    property bool airplaneOn: false

    // ---- UI-Zustand ----
    property bool powerMenuOpen: false
    property bool powerModeOpen: false
    property bool keyboardOpen: false
    property int pendingKbdBrightness: -1
    property var lastSetTs: ({})     // display-id -> Zeitpunkt der letzten lokalen Änderung
    property double kbdLastSetTs: 0

    readonly property var cfg: Plasmoid.configuration
    readonly property bool darkOn: colorScheme === cfg.darkScheme
                                   || colorScheme.toLowerCase().indexOf("dark") !== -1
    readonly property bool anyPowerAction: cfg.showSuspend || cfg.showRestart
                                           || cfg.showShutdown || cfg.showLogout
                                           || cfg.showSwitchUser

    Layout.preferredWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: mainColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    // ---- Befehle ----
    readonly property string qUP: "qdbus6 --system org.freedesktop.UPower /org/freedesktop/UPower/devices/DisplayDevice org.freedesktop.UPower.Device."
    readonly property string qBrightRoot: "qdbus6 org.kde.ScreenBrightness /org/kde/ScreenBrightness"
    readonly property string qKbd: "qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl."
    readonly property string qProfile: "qdbus6 --system org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles.ActiveProfile"
    readonly property string qNight: "qdbus6 org.kde.KWin.NightLight /org/kde/KWin/NightLight org.kde.KWin.NightLight.enabled"

    readonly property string refreshCmd:
        "echo \"KPWR;BAT|$(" + qUP + "Percentage 2>/dev/null)|$(" + qUP + "State 2>/dev/null)|$(" + qUP + "IconName 2>/dev/null)\";" +
        "for d in $(" + qBrightRoot + " org.kde.ScreenBrightness.DisplaysDBusNames 2>/dev/null); do " +
        "echo \"KPWR;DISP|$d|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.Brightness 2>/dev/null)|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.MaxBrightness 2>/dev/null)|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.Label 2>/dev/null)\"; done;" +
        "echo \"KPWR;WIFI|$(LC_ALL=C nmcli radio wifi 2>/dev/null)|$(LC_ALL=C nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | head -n1 | cut -d: -f2-)\";" +
        "echo \"KPWR;BT|$(LC_ALL=C bluetoothctl show 2>/dev/null | grep -m1 'Powered:' | awk '{print $2}')\";" +
        "echo \"KPWR;PROFILE|$(" + qProfile + " 2>/dev/null)\";" +
        "echo \"KPWR;NIGHT|$(" + qNight + " 2>/dev/null)\";" +
        "echo \"KPWR;SCHEME|$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)\";" +
        "echo \"KPWR;KBD|$(" + qKbd + "keyboardBrightness 2>/dev/null)|$(" + qKbd + "keyboardBrightnessMax 2>/dev/null)\";" +
        "echo \"KPWR;PLANE|$(LC_ALL=C rfkill list 2>/dev/null | grep -c 'Soft blocked: yes')|$(LC_ALL=C rfkill list 2>/dev/null | grep -c 'Soft blocked:')\""

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            const stdout = data["stdout"] !== undefined ? data["stdout"] : ""
            disconnectSource(source)
            parseState(stdout)
        }
    }

    function exec(cmd) {
        executable.connectSource(cmd)
    }

    // Der Zeitstempel markiert, wann die Abfrage losgeschickt wurde. Antworten,
    // die älter sind als die letzte lokale Regler-Änderung, werden beim Parsen
    // verworfen, damit sie den frischen Wert nicht überschreiben.
    function refresh() {
        exec("echo \"KPWR;TS|" + Date.now() + "\";" + refreshCmd)
    }

    // Aktion ausführen, kurz warten, dann Zustand neu einlesen
    function toggleAndRefresh(cmd) {
        exec("echo \"KPWR;TS|" + Date.now() + "\";" + cmd + " >/dev/null 2>&1; sleep 0.4; " + refreshCmd)
    }

    function launch(cmd) {
        exec(cmd)
        closePopup()
    }

    function closePopup() {
        if (plasmoidItem) {
            plasmoidItem.expanded = false
        }
    }

    function parseState(out) {
        const lines = out.split("\n")
        const dispIds = []
        const dispInfo = {}
        let requestTs = 0
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (line.indexOf("KPWR;") !== 0) {
                continue
            }
            const parts = line.substring(5).split("|")
            switch (parts[0]) {
            case "TS":
                requestTs = parts[1] ? parseFloat(parts[1]) : 0
                break
            case "BAT":
                batteryPercent = parts[1] ? Math.round(parseFloat(parts[1])) : -1
                batteryState = parts[2] ? parseInt(parts[2]) : 0
                if (parts[3]) {
                    batteryIcon = parts[3]
                }
                break
            case "DISP":
                dispIds.push(parts[1])
                dispInfo[parts[1]] = {
                    brightness: parts[2] ? parseInt(parts[2]) : -1,
                    max: parts[3] ? parseInt(parts[3]) : -1,
                    label: parts.slice(4).join("|")
                }
                break
            case "WIFI":
                wifiOn = parts[1] === "enabled"
                wifiSsid = parts[2] || ""
                break
            case "BT":
                btOn = parts[1] === "yes"
                break
            case "PROFILE":
                powerProfile = parts[1] || ""
                break
            case "NIGHT":
                nightOn = parts[1] === "true"
                break
            case "SCHEME":
                colorScheme = parts[1] || ""
                break
            case "KBD":
                if (requestTs >= kbdLastSetTs) {
                    kbdBrightness = parts[1] ? parseInt(parts[1]) : -1
                }
                kbdMax = parts[2] ? parseInt(parts[2]) : -1
                break
            case "PLANE":
                const blocked = parts[1] ? parseInt(parts[1]) : 0
                const total = parts[2] ? parseInt(parts[2]) : 0
                airplaneOn = total > 0 && blocked === total
                break
            }
        }
        if (dispIds.length > 0) {
            // Repeater-Modell nur ersetzen, wenn sich die Display-Liste
            // wirklich ändert, sonst würde ein laufender Slider-Drag abbrechen
            if (JSON.stringify(dispIds) !== JSON.stringify(displayIds)) {
                displayIds = dispIds
            }
            // Veraltete Antwort (vor der letzten lokalen Änderung gestartet):
            // den optimistisch gesetzten Wert behalten
            for (let d = 0; d < dispIds.length; d++) {
                const id = dispIds[d]
                if (lastSetTs[id] !== undefined && requestTs < lastSetTs[id]
                        && displayInfo[id] !== undefined) {
                    dispInfo[id].brightness = displayInfo[id].brightness
                }
            }
            displayInfo = dispInfo
        }
    }

    // Setzt die Helligkeit und aktualisiert den lokalen Zustand sofort,
    // damit der Regler beim Loslassen nicht auf den alten Wert zurückspringt
    function setDisplayBrightness(id, value) {
        exec(qBrightRoot + "/" + id + " org.kde.ScreenBrightness.Display.SetBrightness " + value + " 1")
        lastSetTs[id] = Date.now()
        if (displayInfo[id]) {
            displayInfo[id].brightness = value
            displayInfo = Object.assign({}, displayInfo)
        }
    }

    function setKbdBrightness(value) {
        exec(qKbd + "setKeyboardBrightnessSilent " + value)
        kbdLastSetTs = Date.now()
        kbdBrightness = value
    }

    function profileLabel(p) {
        switch (p) {
        case "power-saver": return "Energiesparen"
        case "balanced": return "Ausgeglichen"
        case "performance": return "Leistung"
        default: return "Nicht verfügbar"
        }
    }

    function profileIcon(p) {
        switch (p) {
        case "power-saver": return "battery-profile-powersave-symbolic"
        case "performance": return "battery-profile-performance-symbolic"
        default: return "speedometer-symbolic"
        }
    }

    function setProfile(p) {
        toggleAndRefresh(qProfile + " " + p)
        powerModeOpen = false
    }

    function cycleProfile() {
        if (powerProfile === "power-saver") {
            setProfile("balanced")
        } else if (powerProfile === "balanced") {
            setProfile("performance")
        } else {
            setProfile("power-saver")
        }
    }

    Connections {
        target: plasmoidItem
        function onExpandedChanged() {
            if (plasmoidItem.expanded) {
                refresh()
            } else {
                powerMenuOpen = false
                powerModeOpen = false
                keyboardOpen = false
            }
        }
    }

    Timer {
        interval: 3000
        running: plasmoidItem ? plasmoidItem.expanded : false
        repeat: true
        onTriggered: fullRoot.refresh()
    }

    Timer {
        id: kbdTimer
        interval: 150
        onTriggered: {
            if (fullRoot.pendingKbdBrightness >= 0) {
                fullRoot.setKbdBrightness(fullRoot.pendingKbdBrightness)
            }
        }
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ================= Kopfzeile =================
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            // Akku-Pille
            Rectangle {
                visible: fullRoot.cfg.showBattery && fullRoot.batteryPercent >= 0
                implicitHeight: Kirigami.Units.gridUnit * 2.2
                implicitWidth: batteryRow.implicitWidth + Kirigami.Units.largeSpacing * 2
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.12)

                RowLayout {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: fullRoot.batteryIcon
                        fallback: "battery-full-symbolic"
                        color: Kirigami.Theme.textColor
                    }

                    PC3.Label {
                        text: fullRoot.batteryPercent + " %"
                        font.weight: Font.Medium
                    }
                }
            }

            Item { Layout.fillWidth: true }

            HeaderButton {
                visible: fullRoot.cfg.showScreenshot
                icon: "camera-photo-symbolic"
                tooltip: "Bildschirmfoto aufnehmen"
                onClicked: fullRoot.launch("spectacle")
            }

            HeaderButton {
                visible: fullRoot.cfg.showSettings
                icon: "configure-symbolic"
                tooltip: "Systemeinstellungen"
                onClicked: fullRoot.launch("systemsettings")
            }

            HeaderButton {
                visible: fullRoot.cfg.showLock
                icon: "system-lock-screen-symbolic"
                tooltip: "Bildschirm sperren"
                onClicked: fullRoot.launch("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Lock")
            }

            HeaderButton {
                visible: fullRoot.anyPowerAction
                icon: "system-shutdown-symbolic"
                tooltip: "Ausschalten / Abmelden"
                checked: fullRoot.powerMenuOpen
                onClicked: fullRoot.powerMenuOpen = !fullRoot.powerMenuOpen
            }
        }

        // ================= Power-Menü =================
        Rectangle {
            visible: fullRoot.powerMenuOpen && fullRoot.anyPowerAction
            Layout.fillWidth: true
            implicitHeight: powerMenuColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.largeSpacing
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, 0.06)

            ColumnLayout {
                id: powerMenuColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing * 2

                    Rectangle {
                        implicitWidth: Kirigami.Units.gridUnit * 2
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.15)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: "system-shutdown-symbolic"
                            color: Kirigami.Theme.textColor
                        }
                    }

                    PC3.Label {
                        text: "Ausschalten"
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }
                }

                PowerMenuItem {
                    visible: fullRoot.cfg.showSuspend
                    text: "Bereitschaft"
                    onClicked: {
                        fullRoot.closePopup()
                        fullRoot.exec("qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/SuspendSession org.kde.Solid.PowerManagement.Actions.SuspendSession.suspendToRam")
                    }
                }

                PowerMenuItem {
                    visible: fullRoot.cfg.showRestart
                    text: "Neustart…"
                    onClicked: {
                        fullRoot.closePopup()
                        fullRoot.exec("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot")
                    }
                }

                PowerMenuItem {
                    visible: fullRoot.cfg.showShutdown
                    text: "Ausschalten…"
                    onClicked: {
                        fullRoot.closePopup()
                        fullRoot.exec("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptShutDown")
                    }
                }

                Rectangle {
                    visible: (fullRoot.cfg.showSuspend || fullRoot.cfg.showRestart || fullRoot.cfg.showShutdown)
                             && (fullRoot.cfg.showLogout || fullRoot.cfg.showSwitchUser)
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    implicitHeight: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.15)
                }

                PowerMenuItem {
                    visible: fullRoot.cfg.showLogout
                    text: "Abmelden…"
                    onClicked: {
                        fullRoot.closePopup()
                        fullRoot.exec("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout")
                    }
                }

                PowerMenuItem {
                    visible: fullRoot.cfg.showSwitchUser
                    text: "Benutzer wechseln…"
                    onClicked: {
                        fullRoot.closePopup()
                        fullRoot.exec("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Lock; sleep 0.5; qdbus6 --system org.freedesktop.DisplayManager /org/freedesktop/DisplayManager/Seat0 org.freedesktop.DisplayManager.Seat.SwitchToGreeter")
                    }
                }
            }
        }

        // ================= Helligkeit (ein Regler pro Bildschirm) =================
        Repeater {
            model: fullRoot.displayIds

            RowLayout {
                id: brightnessRow

                required property string modelData
                required property int index
                readonly property var info: fullRoot.displayInfo[modelData]
                property int pending: -1

                visible: fullRoot.cfg.showBrightness && info !== undefined && info.max > 0
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    source: "brightness-high-symbolic"
                    color: Kirigami.Theme.textColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PC3.Label {
                        Layout.fillWidth: true
                        visible: fullRoot.displayIds.length > 1
                        text: (brightnessRow.index + 1) + " · "
                              + (brightnessRow.info && brightnessRow.info.label !== ""
                                 ? brightnessRow.info.label
                                 : "Bildschirm")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }

                    PC3.Slider {
                        id: dispSlider
                        Layout.fillWidth: true
                        from: 0
                        to: brightnessRow.info && brightnessRow.info.max > 0
                            ? brightnessRow.info.max : 100
                        stepSize: 1
                        onMoved: {
                            brightnessRow.pending = Math.round(value)
                            dispTimer.restart()
                        }
                        onPressedChanged: {
                            // Beim Loslassen den Endwert sofort übernehmen
                            if (!pressed && brightnessRow.pending >= 0) {
                                dispTimer.stop()
                                fullRoot.setDisplayBrightness(brightnessRow.modelData,
                                                              brightnessRow.pending)
                            }
                        }

                        Binding on value {
                            // Hängt bewusst auch vom Maximum ab, damit die Binding
                            // neu auswertet, sobald "to" seinen echten Wert bekommt
                            value: brightnessRow.info
                                   ? Math.min(brightnessRow.info.brightness, brightnessRow.info.max)
                                   : 0
                            when: !dispSlider.pressed
                                  && brightnessRow.info !== undefined
                                  && brightnessRow.info.brightness >= 0
                        }
                    }
                }

                Timer {
                    id: dispTimer
                    interval: 150
                    onTriggered: {
                        if (brightnessRow.pending >= 0) {
                            fullRoot.setDisplayBrightness(brightnessRow.modelData,
                                                          brightnessRow.pending)
                        }
                    }
                }
            }
        }

        // ================= Schnelleinstellungen =================
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing * 2

            QuickToggle {
                visible: fullRoot.cfg.showWifi
                icon: "network-wireless-symbolic"
                title: "WLAN"
                subtitle: fullRoot.wifiOn ? (fullRoot.wifiSsid !== "" ? fullRoot.wifiSsid : "Nicht verbunden") : "Aus"
                active: fullRoot.wifiOn
                showArrow: true
                onClicked: fullRoot.toggleAndRefresh("nmcli radio wifi " + (fullRoot.wifiOn ? "off" : "on"))
                onArrowClicked: fullRoot.launch("kcmshell6 kcm_networkmanagement")
            }

            QuickToggle {
                visible: fullRoot.cfg.showBluetooth
                icon: "network-bluetooth-symbolic"
                title: "Bluetooth"
                subtitle: fullRoot.btOn ? "An" : "Aus"
                active: fullRoot.btOn
                showArrow: true
                onClicked: fullRoot.toggleAndRefresh("bluetoothctl power " + (fullRoot.btOn ? "off" : "on"))
                onArrowClicked: fullRoot.launch("kcmshell6 kcm_bluetooth")
            }

            QuickToggle {
                visible: fullRoot.cfg.showPowerMode
                icon: fullRoot.profileIcon(fullRoot.powerProfile)
                title: "Energiemodus"
                subtitle: fullRoot.profileLabel(fullRoot.powerProfile)
                active: fullRoot.powerProfile !== "" && fullRoot.powerProfile !== "balanced"
                available: fullRoot.powerProfile !== ""
                showArrow: fullRoot.powerProfile !== ""
                arrowChecked: fullRoot.powerModeOpen
                onClicked: fullRoot.cycleProfile()
                onArrowClicked: {
                    fullRoot.powerModeOpen = !fullRoot.powerModeOpen
                    fullRoot.keyboardOpen = false
                }
            }

            QuickToggle {
                visible: fullRoot.cfg.showNightLight
                icon: "redshift-status-on-symbolic"
                title: "Nachtlicht"
                subtitle: fullRoot.nightOn ? "An" : "Aus"
                active: fullRoot.nightOn
                onClicked: fullRoot.toggleAndRefresh(
                    "kwriteconfig6 --file kwinrc --group NightColor --key Active "
                    + (fullRoot.nightOn ? "false" : "true")
                    + " && qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure")
            }

            QuickToggle {
                visible: fullRoot.cfg.showDarkStyle
                icon: "contrast-symbolic"
                title: "Dunkles Design"
                subtitle: fullRoot.darkOn ? "An" : "Aus"
                active: fullRoot.darkOn
                onClicked: fullRoot.toggleAndRefresh(
                    "plasma-apply-colorscheme "
                    + (fullRoot.darkOn ? fullRoot.cfg.lightScheme : fullRoot.cfg.darkScheme))
            }

            QuickToggle {
                visible: fullRoot.cfg.showKeyboard
                icon: "input-keyboard-symbolic"
                title: "Tastatur"
                subtitle: fullRoot.kbdMax > 0
                          ? (fullRoot.kbdBrightness > 0 ? "Beleuchtung an" : "Beleuchtung aus")
                          : "Keine Beleuchtung"
                active: fullRoot.kbdBrightness > 0
                available: fullRoot.kbdMax > 0
                showArrow: fullRoot.kbdMax > 0
                arrowChecked: fullRoot.keyboardOpen
                onClicked: fullRoot.toggleAndRefresh(
                    fullRoot.qKbd + "setKeyboardBrightnessSilent "
                    + (fullRoot.kbdBrightness > 0 ? 0 : fullRoot.kbdMax))
                onArrowClicked: {
                    fullRoot.keyboardOpen = !fullRoot.keyboardOpen
                    fullRoot.powerModeOpen = false
                }
            }

            QuickToggle {
                visible: fullRoot.cfg.showAirplane
                icon: "network-flightmode-on-symbolic"
                title: "Flugmodus"
                subtitle: fullRoot.airplaneOn ? "An" : "Aus"
                active: fullRoot.airplaneOn
                onClicked: fullRoot.toggleAndRefresh(
                    fullRoot.airplaneOn ? "rfkill unblock all" : "rfkill block all")
            }
        }

        // ================= Energiemodus-Auswahl =================
        Rectangle {
            visible: fullRoot.powerModeOpen && fullRoot.powerProfile !== ""
            Layout.fillWidth: true
            implicitHeight: profileColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.largeSpacing
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, 0.06)

            ColumnLayout {
                id: profileColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: ["power-saver", "balanced", "performance"]

                    PowerMenuItem {
                        required property string modelData
                        text: (fullRoot.powerProfile === modelData ? "●  " : "○  ")
                              + fullRoot.profileLabel(modelData)
                        onClicked: fullRoot.setProfile(modelData)
                    }
                }
            }
        }

        // ================= Tastaturbeleuchtungs-Regler =================
        RowLayout {
            visible: fullRoot.keyboardOpen && fullRoot.kbdMax > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            Kirigami.Icon {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                source: "input-keyboard-symbolic"
                color: Kirigami.Theme.textColor
            }

            PC3.Slider {
                id: kbdSlider
                Layout.fillWidth: true
                from: 0
                to: fullRoot.kbdMax > 0 ? fullRoot.kbdMax : 1
                stepSize: 1
                snapMode: PC3.Slider.SnapAlways
                onMoved: {
                    fullRoot.pendingKbdBrightness = Math.round(value)
                    kbdTimer.restart()
                }
                onPressedChanged: {
                    if (!pressed && fullRoot.pendingKbdBrightness >= 0) {
                        kbdTimer.stop()
                        fullRoot.setKbdBrightness(fullRoot.pendingKbdBrightness)
                    }
                }

                Binding on value {
                    value: Math.min(fullRoot.kbdBrightness, fullRoot.kbdMax)
                    when: !kbdSlider.pressed && fullRoot.kbdBrightness >= 0
                }
            }
        }

        // Schluckt überschüssige Höhe, falls das Widget größer gezogen wird
        Item { Layout.fillHeight: true }
    }
}
