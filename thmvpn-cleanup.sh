#!/bin/bash
# Health-Check und Aufraeumen von Altlasten einer nicht sauber beendeten
# openconnect-Sitzung (Absturz, Ruhezustand, WLAN-Wechsel, kill -9 ...).
# Dann hat das vpnc-script nicht mehr aufgeraeumt und es bleiben zurueck:
#   - die statische Host-Route zum VPN-Gateway (route add -host <gw> ...)
#     -> der naechste Verbindungsversuch scheitert mit
#        "Can't assign requested address"
#   - die DNS-/IPv4-Eintraege des Tunnels im SystemConfiguration-Store
#     (State:/Network/Service/utunN/...) -> Namensaufloesung ueber die
#        THM-Nameserver, die ohne Tunnel nicht erreichbar sind
#
# Aufruf:
#   thmvpn-cleanup.sh --check    nur pruefen (ohne Rechte); gibt je Altlast
#                                eine Zeile aus, Exit 1 = Altlasten gefunden
#   thmvpn-cleanup.sh            aufraeumen; holt sich Root-Rechte wie
#                                thmvpn-disconnect.sh (Touch ID im Terminal,
#                                sonst nativer Admin-Dialog)
#   thmvpn-cleanup.sh --as-root  aufraeumen, setzt Root-Rechte voraus
#
# Laeuft openconnect, gilt nichts als Altlast - dann wird nichts angefasst.
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-cleanup.sh

CONF="$HOME/.config/swiftbar/thmvpn.conf"
[ -f "$CONF" ] && . "$CONF"
HOST="${THM_HOST:-vpn.thm.de}"

# IPv4-Adressen des VPN-Gateways (ueber den Systemresolver, inkl. Cache).
gateway_ips() {
  /usr/bin/dscacheutil -q host -a name "$HOST" | /usr/bin/awk '/^ip_address:/ {print $2}'
}

# Je Altlast eine Zeile "dns <utunN>": vom vpnc-script angelegte
# Tunnel-Dienste, die auf thm.de verweisen und deren utun-Interface nicht mehr
# existiert. Das Interface verschwindet mit dem Prozess, der es geoeffnet hat;
# lebt es noch, gehoert der Eintrag einem aktiven VPN (z.B. Cisco Secure Client).
find_stale_dns() {
  local svc utun
  for svc in $(printf 'list State:/Network/Service/utun[0-9]+/DNS\n' | /usr/sbin/scutil \
                 | /usr/bin/awk '{print $4}'); do
    utun=${svc#State:/Network/Service/}
    utun=${utun%/DNS}
    /sbin/ifconfig "$utun" >/dev/null 2>&1 && continue
    printf 'show %s\n' "$svc" | /usr/sbin/scutil | /usr/bin/grep -q ': thm\.de$' || continue
    echo "dns $utun"
  done
}

# Je Altlast eine Zeile "route <ip>": statische Host-Route zum Gateway.
find_stale_routes() {
  local routes ip
  routes=$(/usr/sbin/netstat -rn -f inet)
  for ip in $(gateway_ips); do
    echo "$routes" | /usr/bin/awk -v ip="$ip" \
      '$1 == ip && $3 ~ /H/ && $3 ~ /S/ {print "route " ip; exit}'
  done
}

# Gibt je Altlast eine Zeile "route <ip>" bzw. "dns <utunN>" aus.
# Solange ein alter THM-DNS-Eintrag existiert, laeuft die Aufloesung von
# vpn.thm.de ins Leere (THM-Nameserver ohne Tunnel unerreichbar) - dann
# wird die Route nicht geprueft; cleanup() holt das nach Entfernen des DNS nach.
find_stale() {
  /usr/bin/pgrep -q -x openconnect && return
  local dns
  dns=$(find_stale_dns)
  if [ -n "$dns" ]; then
    echo "$dns"
  else
    find_stale_routes
  fi
}

cleanup() {
  local kind what n=0
  if /usr/bin/pgrep -q -x openconnect; then
    echo "==> openconnect laeuft noch - nichts angefasst."
    return
  fi
  # Erst DNS entfernen, damit danach das Gateway wieder aufgeloest werden kann.
  while read -r kind what; do
    [[ "$what" =~ ^utun[0-9]+$ ]] || continue
    echo "    Entferne DNS-Eintrag von $what"
    printf 'remove State:/Network/Service/%s/IPv4\nremove State:/Network/Service/%s/DNS\n' \
      "$what" "$what" | /usr/sbin/scutil && n=$((n + 1))
  done < <(find_stale_dns)
  if [ "$n" -gt 0 ]; then
    /usr/bin/dscacheutil -flushcache
    /usr/bin/killall -HUP mDNSResponder 2>/dev/null
  fi
  while read -r kind what; do
    [[ "$what" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || continue
    echo "    Entferne Host-Route zu $what"
    /sbin/route -n delete -host "$what" >/dev/null && n=$((n + 1))
  done < <(find_stale_routes)
  echo "==> $n Altlast(en) entfernt."
}

case "$1" in
  --check)
    STALE=$(find_stale)
    [ -z "$STALE" ] && exit 0
    echo "$STALE"
    exit 1
    ;;
  --as-root)
    if [ "$(id -u)" -ne 0 ]; then
      echo "FEHLER: --as-root braucht Root-Rechte." >&2
      exit 1
    fi
    cleanup
    exit
    ;;
esac

# Ohne Argument: Root-Rechte besorgen, analog zu thmvpn-disconnect.sh.
if /usr/bin/pgrep -q -x openconnect; then
  /usr/bin/osascript -e 'display notification "openconnect laeuft noch - erst trennen." with title "THM-VPN aufraeumen"'
  exit 1
fi

# Touch ID fuer sudo aktiv? sudo braucht dafuer ein TTY, daher ohne Terminal
# (z.B. aus SwiftBar) in einem Terminal-Fenster neu starten.
if /usr/bin/grep -qsE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid' \
     /etc/pam.d/sudo_local /etc/pam.d/sudo; then
  if [ ! -t 0 ]; then
    exec /usr/bin/open -a Terminal "$0"
  fi
  echo "==> Raeume Reste der letzten VPN-Sitzung auf (sudo per Touch ID bestaetigen) ..."
  /usr/bin/sudo "$0" --as-root
  /usr/bin/open -g "swiftbar://refreshplugin?name=thmvpn"
  echo "    Dieses Fenster kann geschlossen werden."
  exit
fi

# Sonst: nativer Admin-Dialog (kein Fenster), Ergebnis als Mitteilung.
RESULT=$(/usr/bin/osascript \
  -e 'on run argv' \
  -e 'do shell script quoted form of (item 1 of argv) & " --as-root" with administrator privileges' \
  -e 'end run' "$0") || exit 1   # Dialog abgebrochen
RESULT=$(echo "$RESULT" | /usr/bin/tr '\r' '\n' | /usr/bin/tail -n 1)
/usr/bin/osascript -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "THM-VPN aufraeumen"' \
  -e 'end run' "${RESULT#==> }"
