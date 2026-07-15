# Power-Menü (GNOME-Stil) für KDE Plasma 6

Ein Plasmoid, das das GNOME-Quick-Settings-Menü nachbildet: Power-Menü,
Akku-Anzeige, Helligkeitsregler und Schnelleinstellungs-Kacheln.

![Vorschau](preview.png)

## Funktionen

**Kopfzeile:** Akku-Anzeige (UPower) · Bildschirmfoto (Spectacle) ·
Systemeinstellungen · Bildschirm sperren · Power-Knopf

**Power-Menü:** Bereitschaft · Neustart… · Ausschalten… · Abmelden… ·
Benutzer wechseln… (die „…“-Einträge zeigen den Plasma-Bestätigungsdialog)

**Regler:** Bildschirmhelligkeit – ein Regler pro erkanntem Bildschirm
(org.kde.ScreenBrightness), bei mehreren Monitoren mit Namensbeschriftung

**Kacheln:** WLAN (nmcli) · Bluetooth (BlueZ-DBus, alle Adapter) ·
Energiemodus (power-profiles-daemon) · Nachtlicht (KWin) · Dunkles Design
(plasma-apply-colorscheme) · Tastaturbeleuchtung (PowerDevil) · Flugmodus
(rfkill)

**Ausklapp-Panels (Pfeil auf der Kachel, animiert, direkt unter der
Kachelzeile):**
- *WLAN:* Netzwerkliste mit Signalstärke, Klick verbindet (bekannte/offene
  Netze; neue passwortgeschützte Netze über „WLAN-Einstellungen“)
- *Bluetooth:* alle gekoppelten Geräte adapterübergreifend, Klick
  verbindet/trennt (koppelt bei Bedarf automatisch); das verbundene Gerät
  erscheint auch als Untertitel der Kachel
- *Energiemodus:* Profilauswahl · *Tastatur:* Helligkeitsregler

Jedes Element lässt sich in den Widget-Einstellungen einzeln ein- und
ausblenden. Die Farbschemata für „Dunkles Design“ sind dort konfigurierbar
(Standard: Breeze / BreezeDark).

## Installation

```sh
./install.sh            # installiert bzw. aktualisiert
```

Danach: Rechtsklick aufs Panel → „Miniprogramme hinzufügen…“ →
„Power-Menü (GNOME-Stil)“.

## Hinweise

- **Energiemodus** benötigt das Paket `power-profiles-daemon`
  (`sudo pacman -S power-profiles-daemon && sudo systemctl enable --now power-profiles-daemon`).
  Ohne den Dienst ist die Kachel ausgegraut.
- **Benutzer wechseln** nutzt `org.freedesktop.DisplayManager` (SDDM/LightDM).
- **Flugmodus** blockiert alle Funkgeräte per `rfkill block all`.
- **Bluetooth** benötigt `python3` und `busctl` (systemd) für die
  adapterübergreifende Geräteliste.
- Die Helligkeitsregler steuern alle von org.kde.ScreenBrightness
  gemeldeten Displays einzeln (intern wie extern/DDC).
