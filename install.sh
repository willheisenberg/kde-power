#!/usr/bin/env bash
# Installiert bzw. aktualisiert das Plasmoid für den aktuellen Benutzer.
set -e
cd "$(dirname "$0")"

if kpackagetool6 -t Plasma/Applet --show com.github.tesla.gnomepower >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi

echo "Fertig. Widget ggf. neu laden mit: systemctl --user restart plasma-plasmashell.service"
