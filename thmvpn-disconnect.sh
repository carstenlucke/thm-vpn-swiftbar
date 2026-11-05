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
#      und beendet openconnect dort per sudo (Touch ID). Das Fenster schliesst
#      sich danach selbst.
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
  OWN_WINDOW_MARKER="${TMPDIR:-/tmp}/thmvpn-own-window.$(basename "$0")"
  if [ ! -t 0 ]; then
    /usr/bin/touch "$OWN_WINDOW_MARKER"
    exec /usr/bin/open -a Terminal "$0"
  fi
  OWN_WINDOW=0
  # Nur ein frischer Marker zaehlt: ein liegengebliebener (open gescheitert)
  # darf kein von Hand geoeffnetes Fenster schliessen.
  [ -n "$(/usr/bin/find "$OWN_WINDOW_MARKER" -mtime -60s 2>/dev/null)" ] && OWN_WINDOW=1
  /bin/rm -f "$OWN_WINDOW_MARKER"
  echo "==> Trenne THM-VPN (sudo per Touch ID bestaetigen) ..."
  /usr/bin/sudo /usr/bin/pkill -INT openconnect
  STATUS=$?
  sleep 2
  /usr/bin/open -g "swiftbar://refreshplugin?name=thmvpn"
  if [ "$STATUS" -eq 0 ]; then
    echo "==> Fertig - der Menueleisten-Status ist aktualisiert."
  else
    echo "==> Trennen fehlgeschlagen (Status $STATUS) - kein openconnect beendet."
  fi
  CLOSE_WINDOW="$(dirname "$0")/thmvpn-closewindow.sh"
  if [ "$STATUS" -eq 0 ] && [ "$OWN_WINDOW" -eq 1 ] && [ -x "$CLOSE_WINDOW" ]; then
    nohup "$CLOSE_WINDOW" "$(tty)" "$$" </dev/null >/dev/null 2>&1 &
    disown
  else
    echo "    Dieses Fenster kann geschlossen werden."
  fi
  exit
fi

# Fall 3: weder sudoers noch Touch ID -> nativer Admin-Dialog (kein Fenster).
/usr/bin/osascript -e 'do shell script "/usr/bin/pkill -INT openconnect" with administrator privileges'
sleep 2
