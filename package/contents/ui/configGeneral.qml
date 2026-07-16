import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Kopfzeile
    property alias cfg_showBattery: showBattery.checked
    property alias cfg_showScreenshot: showScreenshot.checked
    property alias cfg_showSettings: showSettings.checked
    property alias cfg_showLock: showLock.checked

    // Power-Menü
    property alias cfg_showSuspend: showSuspend.checked
    property alias cfg_showHibernate: showHibernate.checked
    property alias cfg_showHybridSuspend: showHybridSuspend.checked
    property alias cfg_showRestart: showRestart.checked
    property alias cfg_showShutdown: showShutdown.checked
    property alias cfg_showLogout: showLogout.checked
    property alias cfg_showSwitchUser: showSwitchUser.checked

    // Regler
    property alias cfg_showVolume: showVolume.checked
    property alias cfg_showBrightness: showBrightness.checked

    // Schnelleinstellungen
    property alias cfg_showWifi: showWifi.checked
    property alias cfg_showBluetooth: showBluetooth.checked
    property alias cfg_showPowerMode: showPowerMode.checked
    property alias cfg_showNightLight: showNightLight.checked
    property alias cfg_showDarkStyle: showDarkStyle.checked
    property alias cfg_showKeyboard: showKeyboard.checked
    property alias cfg_showAirplane: showAirplane.checked
    property alias cfg_showDnd: showDnd.checked
    property alias cfg_showMic: showMic.checked
    property alias cfg_showRecording: showRecording.checked

    // Farbschemata
    property alias cfg_lightScheme: lightScheme.text
    property alias cfg_darkScheme: darkScheme.text

    Kirigami.FormLayout {

        Item {
            Kirigami.FormData.label: "Kopfzeile"
            Kirigami.FormData.isSection: true
        }
        QQC2.CheckBox { id: showBattery; text: "Akkuanzeige" }
        QQC2.CheckBox { id: showScreenshot; text: "Bildschirmfoto-Knopf" }
        QQC2.CheckBox { id: showSettings; text: "Einstellungen-Knopf" }
        QQC2.CheckBox { id: showLock; text: "Sperren-Knopf" }

        Item {
            Kirigami.FormData.label: "Power-Menü"
            Kirigami.FormData.isSection: true
        }
        QQC2.CheckBox { id: showSuspend; text: "Bereitschaft" }
        QQC2.CheckBox { id: showHibernate; text: "Ruhezustand" }
        QQC2.CheckBox { id: showHybridSuspend; text: "Hybrider Standby" }
        QQC2.CheckBox { id: showRestart; text: "Neustart" }
        QQC2.CheckBox { id: showShutdown; text: "Ausschalten" }
        QQC2.CheckBox { id: showLogout; text: "Abmelden" }
        QQC2.CheckBox { id: showSwitchUser; text: "Benutzer wechseln" }

        Item {
            Kirigami.FormData.label: "Regler"
            Kirigami.FormData.isSection: true
        }
        QQC2.CheckBox { id: showVolume; text: "Lautstärke" }
        QQC2.CheckBox { id: showBrightness; text: "Bildschirmhelligkeit" }

        Item {
            Kirigami.FormData.label: "Schnelleinstellungen"
            Kirigami.FormData.isSection: true
        }
        QQC2.CheckBox { id: showWifi; text: "WLAN" }
        QQC2.CheckBox { id: showBluetooth; text: "Bluetooth" }
        QQC2.CheckBox {
            id: showPowerMode
            text: "Energiemodus"
        }
        QQC2.Label {
            visible: showPowerMode.checked
            text: "Benötigt das Paket „power-profiles-daemon“."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox { id: showNightLight; text: "Nachtlicht" }
        QQC2.CheckBox { id: showDarkStyle; text: "Dunkles Design" }
        QQC2.CheckBox { id: showKeyboard; text: "Tastaturbeleuchtung" }
        QQC2.CheckBox { id: showAirplane; text: "Flugmodus" }
        QQC2.CheckBox { id: showDnd; text: "Bitte nicht stören" }
        QQC2.CheckBox { id: showMic; text: "Mikrofon stumm" }
        QQC2.CheckBox { id: showRecording; text: "Bildschirmaufnahme" }

        Item {
            Kirigami.FormData.label: "Farbschemata für „Dunkles Design“"
            Kirigami.FormData.isSection: true
        }
        QQC2.TextField {
            id: lightScheme
            Kirigami.FormData.label: "Helles Schema:"
        }
        QQC2.TextField {
            id: darkScheme
            Kirigami.FormData.label: "Dunkles Schema:"
        }
        QQC2.Label {
            text: "Verfügbare Schemata: plasma-apply-colorscheme --list-schemes"
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
