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
if [ ! -t 0 ]; then
  exec /usr/bin/open -a Terminal "$0"
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

sudo openconnect "${ARGS[@]}" "$HOST"

echo
echo "==> openconnect beendet. Dieses Fenster kann geschlossen werden."