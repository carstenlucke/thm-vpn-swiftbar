#!/bin/bash
# Beendet openconnect sauber per SIGINT, damit das vpnc-script Routen/DNS
# zuruecksetzt (so, als haette man im Terminal Strg-C gedrueckt).
#
# openconnect laeuft als root (via sudo), daher braucht das Beenden Rechte.
# Der Weg wird automatisch gewaehlt:
#   1. sudoers-Eintrag /etc/sudoers.d/openconnect-disconnect vorhanden
#      -> passwortlos, ohne Dialog und ohne Fenster.
#   2. Touch ID fuer sudo aktiv (pam_tid) -> da sudo/Touch ID ein TTY braucht,
#      startet sich das Skript in einem Terminal-Fenster neu (open -a Terminal)
#      und beendet openconnect dort per sudo (Touch ID).
#   3. sonst -> nativer macOS-Admin-Dialog (Passwort, ohne Fenster).
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-disconnect.sh

# Fall 1: passwortlos via sudoers -> kein Terminal noetig.
if [ -f /etc/sudoers.d/openconnect-disconnect ]; then
  /usr/bin/sudo -n /usr/bin/pkill -INT openconnect
  exit
fi

# Fall 2: Touch ID fuer sudo aktiv? sudo braucht dafuer ein TTY, daher ohne
# Terminal (z.B. aus SwiftBar) in einem Terminal-Fenster neu starten.
if /usr/bin/grep -qsE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid' \
     /etc/pam.d/sudo_local /etc/pam.d/sudo; then
  if [ ! -t 0 ]; then
    exec /usr/bin/open -a Terminal "$0"
  fi
  echo "==> Trenne THM-VPN (sudo per Touch ID bestaetigen) ..."
  /usr/bin/sudo /usr/bin/pkill -INT openconnect
  sleep 2
  echo "==> Fertig - der Menueleisten-Status aktualisiert sich gleich."
  echo "    Dieses Fenster kann geschlossen werden."
  exit
fi

# Fall 3: weder sudoers noch Touch ID -> nativer Admin-Dialog (kein Fenster).
/usr/bin/osascript -e 'do shell script "/usr/bin/pkill -INT openconnect" with administrator privileges'
sleep 2
