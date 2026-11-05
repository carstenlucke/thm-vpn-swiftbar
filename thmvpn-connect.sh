#!/bin/bash
# Baut die THM-VPN-Verbindung per openconnect auf. Das SwiftBar-Plugin ruft
# dieses Skript im Hintergrund auf (terminal=false); laeuft es ohne Terminal,
# startet es sich selbst in einem Terminal-Fenster neu (open -a Terminal),
# damit openconnect interaktiv nach sudo-/VPN-Passwort (und ggf. zweitem
# Faktor / Gruppe) fragen und im Vordergrund laufen kann.
#
# Konfiguration (optional) in ~/.config/swiftbar/thmvpn.conf:
#   THM_USER=<rz-kennung>     # weglassen -> openconnect fragt interaktiv
#   THM_HOST=vpn.thm.de       # Standard
#   THM_AUTHGROUP=<gruppe>    # nur falls beim Login eine Gruppe gewaehlt wird
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-connect.sh

# Ohne Terminal gestartet (z.B. von SwiftBar)? -> in einem Terminal neu starten.
# Die Markerdatei merkt sich, dass das Fenster nur fuer dieses Skript geoeffnet
# wurde und am Ende wieder geschlossen werden darf.
OWN_WINDOW_MARKER="${TMPDIR:-/tmp}/thmvpn-own-window"
if [ ! -t 0 ]; then
  /usr/bin/touch "$OWN_WINDOW_MARKER"
  exec /usr/bin/open -a Terminal "$0"
fi
OWN_WINDOW=0
if [ -f "$OWN_WINDOW_MARKER" ]; then
  /bin/rm -f "$OWN_WINDOW_MARKER"
  OWN_WINDOW=1
fi

CONF="$HOME/.config/swiftbar/thmvpn.conf"
[ -f "$CONF" ] && . "$CONF"

HOST="${THM_HOST:-vpn.thm.de}"

ARGS=(--protocol=anyconnect)
[ -n "${THM_USER:-}" ]      && ARGS+=(--user="$THM_USER")
[ -n "${THM_AUTHGROUP:-}" ] && ARGS+=(--authgroup="$THM_AUTHGROUP")

echo "==> Verbinde mit $HOST"
echo "    sudo- und VPN-Passwort eingeben (ggf. zweiter Faktor)."
echo "    Trennen: Strg-C in diesem Fenster oder Menuepunkt 'VPN trennen'."
echo

# Reste einer nicht sauber beendeten Sitzung (v.a. die alte Host-Route zum
# Gateway) lassen den Verbindungsaufbau scheitern -> vorher aufraeumen.
CLEANUP="$(dirname "$0")/thmvpn-cleanup.sh"
if [ -x "$CLEANUP" ] && ! "$CLEANUP" --check >/dev/null; then
  echo "==> Raeume Reste der letzten VPN-Sitzung auf"
  sudo "$CLEANUP" --as-root
  echo
fi

sudo openconnect "${ARGS[@]}" "$HOST"
STATUS=$?

echo
# Nach sauberem Trennen raeumt sich das eigene Fenster selbst weg; bei einem
# Fehler bleibt es offen, damit die Meldung lesbar ist.
CLOSE_WINDOW="$(dirname "$0")/thmvpn-closewindow.sh"
if [ "$STATUS" -eq 0 ] && [ "$OWN_WINDOW" -eq 1 ] && [ -x "$CLOSE_WINDOW" ]; then
  echo "==> openconnect beendet. Dieses Fenster schliesst sich."
  nohup "$CLOSE_WINDOW" "$(tty)" </dev/null >/dev/null 2>&1 &
  disown
else
  echo "==> openconnect beendet (Status $STATUS). Dieses Fenster kann geschlossen werden."
fi