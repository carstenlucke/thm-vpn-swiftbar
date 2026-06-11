#!/bin/bash
# Beendet openconnect sauber per SIGINT, damit das vpnc-script Routen/DNS
# zuruecksetzt (so, als haette man im Terminal Strg-C gedrueckt).
#
# openconnect laeuft als root (via sudo), daher braucht das Beenden
# Admin-Rechte. Zwei Wege, automatisch erkannt:
#   - Liegt der optionale sudoers-Eintrag vor
#     (/etc/sudoers.d/openconnect-disconnect), wird openconnect OHNE
#     Passwortdialog beendet.
#   - Sonst zeigt macOS den nativen Passwortdialog (Auth ~5 Min. gecacht).
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-disconnect.sh
# und wird vom SwiftBar-Plugin (Menuepunkt "VPN trennen") aufgerufen.

if [ -f /etc/sudoers.d/openconnect-disconnect ]; then
  /usr/bin/sudo -n /usr/bin/pkill -INT openconnect
else
  /usr/bin/osascript -e 'do shell script "/usr/bin/pkill -INT openconnect" with administrator privileges'
fi

# Kurz warten, damit openconnect aufgeraeumt hat, bevor SwiftBar das
# Plugin neu zeichnet (sonst zeigt es kurz noch das Schloss).
sleep 2
