#!/bin/bash
# Beendet openconnect sauber per SIGINT, damit das vpnc-script Routen/DNS
# zuruecksetzt. openconnect laeuft als root (via sudo), daher braucht das
# Beenden Admin-Rechte: macOS zeigt einen nativen Passwortdialog
# (Authentifizierung wird ca. 5 Minuten gecacht).
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-disconnect.sh
# und wird vom SwiftBar-Plugin (Menuepunkt "VPN trennen") aufgerufen.
/usr/bin/osascript -e 'do shell script "/usr/bin/pkill -INT openconnect" with administrator privileges'

# Kurz warten, damit openconnect aufgeraeumt hat, bevor SwiftBar das
# Plugin neu zeichnet (sonst zeigt es kurz noch das Schloss).
sleep 2
