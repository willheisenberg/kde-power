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
    property int btConnCount: 0
    property string btConnName: ""
    property string powerProfile: ""        // leer = power-profiles-daemon fehlt
    property bool nightOn: false
    property string colorScheme: ""
    property int kbdBrightness: -1
    property int kbdMax: -1
    property bool airplaneOn: false

    // ---- Ausklapp-Panels (Geräte-/Netzwerklisten) ----
    property var btDevices: []       // { path, mac, connected, icon, name }
    property var btAdapters: []      // { path, powered }
    property var wifiNets: []        // { inUse, ssid, signal, secured }

    // ---- UI-Zustand ----
    property bool powerMenuOpen: false
    property bool powerModeOpen: false
    property bool keyboardOpen: false
    property bool wifiPanelOpen: false
    property bool btPanelOpen: false
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
    // "running" statt "enabled": spiegelt den tatsächlichen Zustand inkl.
    // Inhibierung wider, die der Umschalt-Shortcut verwendet
    readonly property string qNight: "qdbus6 org.kde.KWin.NightLight /org/kde/KWin/NightLight org.kde.KWin.NightLight.running"

    readonly property string refreshCmd:
        "echo \"KPWR;BAT|$(" + qUP + "Percentage 2>/dev/null)|$(" + qUP + "State 2>/dev/null)|$(" + qUP + "IconName 2>/dev/null)\";" +
        "for d in $(" + qBrightRoot + " org.kde.ScreenBrightness.DisplaysDBusNames 2>/dev/null); do " +
        "echo \"KPWR;DISP|$d|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.Brightness 2>/dev/null)|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.MaxBrightness 2>/dev/null)|$(" + qBrightRoot + "/$d org.kde.ScreenBrightness.Display.Label 2>/dev/null)\"; done;" +
        "echo \"KPWR;WIFI|$(LC_ALL=C nmcli radio wifi 2>/dev/null)|$(LC_ALL=C nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | head -n1 | cut -d: -f2-)\";" +
        "echo \"KPWR;PROFILE|$(" + qProfile + " 2>/dev/null)\";" +
        "echo \"KPWR;NIGHT|$(" + qNight + " 2>/dev/null)\";" +
        "echo \"KPWR;SCHEME|$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)\";" +
        "echo \"KPWR;KBD|$(" + qKbd + "keyboardBrightness 2>/dev/null)|$(" + qKbd + "keyboardBrightnessMax 2>/dev/null)\";" +
        "echo \"KPWR;PLANE|$(LC_ALL=C rfkill list 2>/dev/null | grep -c 'Soft blocked: yes')|$(LC_ALL=C rfkill list 2>/dev/null | grep -c 'Soft blocked:')\";" +
        btListCmd

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

    // Adapter und Geräte ALLER Bluetooth-Controller über die BlueZ-DBus-API
    // (bluetoothctl zeigt nur den Standard-Controller und übersieht Geräte,
    // die an einem zweiten Adapter hängen)
    readonly property string btListCmd:
        "echo \"KPWR;BTLIST\";" +
        "busctl --system call org.bluez / org.freedesktop.DBus.ObjectManager GetManagedObjects --json=short 2>/dev/null" +
        " | python3 -c 'import json,sys\n" +
        "try:\n" +
        " d=json.load(sys.stdin)[\"data\"][0]\n" +
        "except Exception:\n" +
        " d={}\n" +
        "for p,i in sorted(d.items()):\n" +
        " a=i.get(\"org.bluez.Adapter1\")\n" +
        " if a:\n" +
        "  print(\"KPWR;BTADP|%s|%d\"%(p,1 if a.get(\"Powered\",{}).get(\"data\",False) else 0))\n" +
        " v=i.get(\"org.bluez.Device1\")\n" +
        " if not v:\n" +
        "  continue\n" +
        " c=v.get(\"Connected\",{}).get(\"data\",False)\n" +
        " ic=(v.get(\"Icon\") or {}).get(\"data\") or \"network-bluetooth\"\n" +
        " print(\"KPWR;BTDEV|%s|%s|%d|%s|%s\"%(p,v[\"Address\"][\"data\"],1 if c else 0,ic,v.get(\"Alias\",{}).get(\"data\",\"?\")))' 2>/dev/null"

    // Netzwerkliste (nur abgefragt, wenn das WLAN-Panel offen ist)
    readonly property string wifiListCmd:
        "echo \"KPWR;WIFILIST\";" +
        "LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null" +
        " | sed 's/^/KPWR;WIFINET|/'"

    function refreshPayload() {
        let c = refreshCmd
        if (wifiPanelOpen) {
            c += ";" + wifiListCmd
        }
        return c
    }

    // Der Zeitstempel markiert, wann die Abfrage losgeschickt wurde. Antworten,
    // die älter sind als die letzte lokale Regler-Änderung, werden beim Parsen
    // verworfen, damit sie den frischen Wert nicht überschreiben.
    function refresh() {
        exec("echo \"KPWR;TS|" + Date.now() + "\";" + refreshPayload())
    }

    // Aktion ausführen, kurz warten, dann Zustand neu einlesen
    function toggleAndRefresh(cmd) {
        exec("echo \"KPWR;TS|" + Date.now() + "\";" + cmd + " >/dev/null 2>&1; sleep 0.4; " + refreshPayload())
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function wifiSignalIcon(s) {
        if (s >= 80) return "network-wireless-signal-excellent-symbolic"
        if (s >= 55) return "network-wireless-signal-good-symbolic"
        if (s >= 30) return "network-wireless-signal-ok-symbolic"
        if (s > 0) return "network-wireless-signal-weak-symbolic"
        return "network-wireless-signal-none-symbolic"
    }

    function closePanels() {
        powerModeOpen = false
        keyboardOpen = false
        wifiPanelOpen = false
        btPanelOpen = false
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
        const btList = []
        const adpList = []
        let btSeen = false
        const wifiRaw = []
        let wifiSeen = false
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
            case "PROFILE":
                powerProfile = parts[1] || ""
                break
            case "NIGHT":
                nightOn = parts[1] === "true"
                break
            case "SCHEME":
                colorScheme = parts[1] || ""
                break
            case "BTLIST":
                btSeen = true
                break
            case "BTADP":
                adpList.push({
                    path: parts[1],
                    powered: parts[2] === "1"
                })
                break
            case "BTDEV":
                btList.push({
                    path: parts[1],
                    mac: parts[2],
                    connected: parts[3] === "1",
                    icon: parts[4] || "network-bluetooth",
                    name: parts.slice(5).join("|")
                })
                break
            case "WIFILIST":
                wifiSeen = true
                break
            case "WIFINET": {
                // nmcli -t: IN-USE:SSID:SIGNAL:SECURITY, Doppelpunkte in der
                // SSID sind als \: maskiert
                const f = parts.slice(1).join("|").split(":")
                if (f.length >= 4) {
                    const ssid = f.slice(1, f.length - 2).join(":").replace(/\\:/g, ":")
                    if (ssid !== "") {
                        wifiRaw.push({
                            inUse: f[0] === "*",
                            ssid: ssid,
                            signal: parseInt(f[f.length - 2]) || 0,
                            secured: f[f.length - 1] !== "" && f[f.length - 1] !== "--"
                        })
                    }
                }
                break
            }
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
                const stale = lastSetTs[id] !== undefined && requestTs < lastSetTs[id]
                if (stale && displayInfo[id] !== undefined) {
                    dispInfo[id].brightness = displayInfo[id].brightness
                }
            }
            displayInfo = dispInfo
        }
        if (btSeen) {
            btAdapters = adpList
            let anyPowered = false
            for (let i = 0; i < adpList.length; i++) {
                if (adpList[i].powered) {
                    anyPowered = true
                }
            }
            btOn = anyPowered
            // Verbundene Geräte zuerst
            btList.sort(function (a, b) {
                return b.connected - a.connected
            })
            let connCount = 0
            let firstName = ""
            for (let i = 0; i < btList.length; i++) {
                if (btList[i].connected) {
                    connCount++
                    if (firstName === "") {
                        firstName = btList[i].name
                    }
                }
            }
            btConnCount = connCount
            btConnName = firstName
            if (JSON.stringify(btList) !== JSON.stringify(btDevices)) {
                btDevices = btList
            }
        }
        if (wifiSeen) {
            // Pro SSID nur den besten Eintrag behalten, verbundenes Netz zuerst
            const bySsid = {}
            for (let i = 0; i < wifiRaw.length; i++) {
                const n = wifiRaw[i]
                const e = bySsid[n.ssid]
                if (e === undefined || (n.inUse && !e.inUse)
                        || (n.inUse === e.inUse && n.signal > e.signal)) {
                    bySsid[n.ssid] = n
                }
            }
            const keys = Object.keys(bySsid)
            let nets = []
            for (let i = 0; i < keys.length; i++) {
                nets.push(bySsid[keys[i]])
            }
            nets.sort(function (a, b) {
                return (b.inUse - a.inUse) || (b.signal - a.signal)
            })
            nets = nets.slice(0, 7)
            if (JSON.stringify(nets) !== JSON.stringify(wifiNets)) {
                wifiNets = nets
            }
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
                fullRoot.closePanels()
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

                onInfoChanged: dispSlider.sync()

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

                        // Kein "Binding on value": das Binding-Element friert beim
                        // Deaktivieren (während des Ziehens) seinen Auswertungsstand
                        // ein und schreibt beim Loslassen den alten Wert zurück.
                        // Stattdessen wird der Wert explizit synchronisiert.
                        function sync() {
                            if (!pressed && brightnessRow.info
                                    && brightnessRow.info.brightness >= 0) {
                                value = Math.min(brightnessRow.info.brightness,
                                                 brightnessRow.info.max)
                            }
                        }

                        Component.onCompleted: sync()
                        onToChanged: sync()
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
                            sync()
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
                arrowChecked: fullRoot.wifiPanelOpen
                onClicked: fullRoot.toggleAndRefresh("nmcli radio wifi " + (fullRoot.wifiOn ? "off" : "on"))
                onArrowClicked: {
                    const open = !fullRoot.wifiPanelOpen
                    fullRoot.closePanels()
                    fullRoot.wifiPanelOpen = open
                    if (open) {
                        fullRoot.exec("nmcli dev wifi rescan >/dev/null 2>&1")
                        fullRoot.refresh()
                    }
                }
            }

            QuickToggle {
                visible: fullRoot.cfg.showBluetooth
                icon: "network-bluetooth-symbolic"
                title: "Bluetooth"
                subtitle: !fullRoot.btOn ? "Aus"
                          : fullRoot.btConnCount > 1 ? fullRoot.btConnCount + " Geräte verbunden"
                          : fullRoot.btConnName !== "" ? fullRoot.btConnName
                          : "An"
                active: fullRoot.btOn
                showArrow: true
                arrowChecked: fullRoot.btPanelOpen
                onClicked: {
                    // Alle Adapter schalten, nicht nur den Standard-Controller
                    const cmds = []
                    for (let i = 0; i < fullRoot.btAdapters.length; i++) {
                        cmds.push("busctl --system set-property org.bluez "
                                  + fullRoot.btAdapters[i].path
                                  + " org.bluez.Adapter1 Powered b "
                                  + (fullRoot.btOn ? "false" : "true"))
                    }
                    fullRoot.toggleAndRefresh(cmds.length > 0
                        ? cmds.join("; ")
                        : "bluetoothctl power " + (fullRoot.btOn ? "off" : "on"))
                }
                onArrowClicked: {
                    const open = !fullRoot.btPanelOpen
                    fullRoot.closePanels()
                    fullRoot.btPanelOpen = open
                    if (open) {
                        fullRoot.refresh()
                    }
                }
            }

            // ---- WLAN-Panel (klappt unter der Kachelzeile aus) ----
            ExpandingCard {
                Layout.columnSpan: 2
                open: fullRoot.wifiPanelOpen && fullRoot.cfg.showWifi

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing * 2

                    Rectangle {
                        implicitWidth: Kirigami.Units.gridUnit * 2
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: fullRoot.wifiOn
                               ? Kirigami.Theme.highlightColor
                               : Qt.rgba(Kirigami.Theme.textColor.r,
                                         Kirigami.Theme.textColor.g,
                                         Kirigami.Theme.textColor.b, 0.15)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: "network-wireless-symbolic"
                            color: fullRoot.wifiOn
                                   ? Kirigami.Theme.highlightedTextColor
                                   : Kirigami.Theme.textColor
                        }
                    }

                    PC3.Label {
                        text: "WLAN"
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }
                }

                PC3.Label {
                    visible: fullRoot.wifiNets.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    text: fullRoot.wifiOn ? "Suche Netzwerke…" : "WLAN ist ausgeschaltet"
                    opacity: 0.7
                }

                Repeater {
                    model: fullRoot.wifiNets

                    PanelItem {
                        required property var modelData
                        icon: fullRoot.wifiSignalIcon(modelData.signal)
                        fallbackIcon: "network-wireless-symbolic"
                        text: modelData.ssid
                        trailing: modelData.inUse ? "Verbunden" : ""
                        bold: modelData.inUse
                        onClicked: {
                            if (!modelData.inUse) {
                                fullRoot.toggleAndRefresh("nmcli dev wifi connect "
                                                          + fullRoot.shellQuote(modelData.ssid))
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    implicitHeight: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.15)
                }

                PanelItem {
                    text: "WLAN-Einstellungen"
                    onClicked: fullRoot.launch("kcmshell6 kcm_networkmanagement")
                }
            }

            // ---- Bluetooth-Panel (klappt unter der Kachelzeile aus) ----
            ExpandingCard {
                Layout.columnSpan: 2
                open: fullRoot.btPanelOpen && fullRoot.cfg.showBluetooth

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing * 2

                    Rectangle {
                        implicitWidth: Kirigami.Units.gridUnit * 2
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: fullRoot.btOn
                               ? Kirigami.Theme.highlightColor
                               : Qt.rgba(Kirigami.Theme.textColor.r,
                                         Kirigami.Theme.textColor.g,
                                         Kirigami.Theme.textColor.b, 0.15)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: "network-bluetooth-symbolic"
                            color: fullRoot.btOn
                                   ? Kirigami.Theme.highlightedTextColor
                                   : Kirigami.Theme.textColor
                        }
                    }

                    PC3.Label {
                        text: "Bluetooth"
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }
                }

                PC3.Label {
                    visible: fullRoot.btDevices.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    text: fullRoot.btOn ? "Keine gekoppelten Geräte" : "Bluetooth ist ausgeschaltet"
                    opacity: 0.7
                }

                Repeater {
                    model: fullRoot.btDevices

                    PanelItem {
                        required property var modelData
                        icon: modelData.icon
                        fallbackIcon: "network-bluetooth"
                        text: modelData.name
                        trailing: modelData.connected ? "Trennen" : "Verbinden"
                        bold: modelData.connected
                        onClicked: {
                            // Über den DBus-Pfad, damit auch Geräte an einem
                            // zweiten Adapter funktionieren. Falls noch nicht
                            // gekoppelt: erst vertrauen + koppeln.
                            const dev = "busctl --system call org.bluez "
                                        + modelData.path + " org.bluez.Device1 "
                            const cmd = modelData.connected
                                ? dev + "Disconnect"
                                : dev + "Connect || { busctl --system set-property org.bluez "
                                  + modelData.path + " org.bluez.Device1 Trusted b true; "
                                  + dev + "Pair; " + dev + "Connect; }"
                            fullRoot.toggleAndRefresh(cmd)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    implicitHeight: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.15)
                }

                PanelItem {
                    text: "Bluetooth-Einstellungen"
                    onClicked: fullRoot.launch("kcmshell6 kcm_bluetooth")
                }
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
                    const open = !fullRoot.powerModeOpen
                    fullRoot.closePanels()
                    fullRoot.powerModeOpen = open
                }
            }

            QuickToggle {
                visible: fullRoot.cfg.showNightLight
                icon: "redshift-status-on-symbolic"
                title: "Nachtlicht"
                subtitle: fullRoot.nightOn ? "An" : "Aus"
                active: fullRoot.nightOn
                // Offizieller Umschaltweg: derselbe wie die Tastenkombination.
                // kwinrc-Schreibzugriffe wendet KWin nicht zuverlässig an.
                onClicked: fullRoot.toggleAndRefresh(
                    "qdbus6 org.kde.kglobalaccel /component/kwin"
                    + " org.kde.kglobalaccel.Component.invokeShortcut \"Toggle Night Color\"")
            }

            // ---- Energiemodus-Auswahl (klappt unter der Kachelzeile aus) ----
            ExpandingCard {
                Layout.columnSpan: 2
                open: fullRoot.powerModeOpen && fullRoot.powerProfile !== ""

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
                    const open = !fullRoot.keyboardOpen
                    fullRoot.closePanels()
                    fullRoot.keyboardOpen = open
                }
            }

            // ---- Tastaturbeleuchtungs-Regler (klappt unter der Kachelzeile aus) ----
            ExpandingCard {
                Layout.columnSpan: 2
                open: fullRoot.keyboardOpen && fullRoot.kbdMax > 0

                RowLayout {
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

                        function sync() {
                            if (!pressed && fullRoot.kbdBrightness >= 0 && fullRoot.kbdMax > 0) {
                                value = Math.min(fullRoot.kbdBrightness, fullRoot.kbdMax)
                            }
                        }

                        Component.onCompleted: sync()
                        onToChanged: sync()
                        onMoved: {
                            fullRoot.pendingKbdBrightness = Math.round(value)
                            kbdTimer.restart()
                        }
                        onPressedChanged: {
                            if (!pressed && fullRoot.pendingKbdBrightness >= 0) {
                                kbdTimer.stop()
                                fullRoot.setKbdBrightness(fullRoot.pendingKbdBrightness)
                            }
                            sync()
                        }

                        Connections {
                            target: fullRoot
                            function onKbdBrightnessChanged() { kbdSlider.sync() }
                        }
                    }
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


        // Schluckt überschüssige Höhe, falls das Widget größer gezogen wird
        Item { Layout.fillHeight: true }
    }
}
