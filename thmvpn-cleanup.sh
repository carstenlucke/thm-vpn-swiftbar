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
#   - die per networksetup am aktiven Netzwerkdienst gesetzten THM-Nameserver
#   - im Full-Tunnel die allgemeine Default-Route: das vpnc-script ersetzt sie
#     durch eine Route ueber den Tunnel, die mit dem utun-Interface verschwindet
#     -> kein Internet; das alte Gateway steht in /var/run/vpnc/defaultroute.<pid>
#
# Aufruf:
#   thmvpn-cleanup.sh --check    nur pruefen (ohne Rechte); gibt je Altlast
#                                eine Zeile aus, Exit 1 = Altlasten gefunden
#   thmvpn-cleanup.sh            aufraeumen; holt sich Root-Rechte wie
#                                thmvpn-disconnect.sh (Touch ID im Terminal,
#                                sonst nativer Admin-Dialog)
#   thmvpn-cleanup.sh --as-root  aufraeumen, setzt Root-Rechte voraus
#
# Laeuft openconnect oder ein anderer THM-VPN-Client (Tunnel-Adresse 10.196.x),
# gilt nichts als Altlast - dann wird nichts angefasst.
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-cleanup.sh

CONF="$HOME/.config/swiftbar/thmvpn.conf"
[ -f "$CONF" ] && . "$CONF"
HOST="${THM_HOST:-vpn.thm.de}"

# IPv4-Adressen des VPN-Gateways (ueber den Systemresolver, inkl. Cache).
gateway_ips() {
  /usr/bin/dscacheutil -q host -a name "$HOST" | /usr/bin/awk '/^ip_address:/ {print $2}'
}

# Laeuft gerade ein VPN zur THM? openconnect selbst oder ein anderer Client
# (z.B. Cisco Secure Client) mit Tunnel-Adresse 10.196.x - dann ist nichts
# eine Altlast, auch nicht dessen Host-Route zum Gateway.
vpn_active() {
  /usr/bin/pgrep -q -x openconnect || /sbin/ifconfig | /usr/bin/grep -q 'inet 10\.196\.'
}

# Einzelwert (z.B. Router) aus einem SystemConfiguration-Key.
sc_value() {
  printf 'show %s\n' "$1" | /usr/sbin/scutil | /usr/bin/awk -v k="$2" '$1 == k {print $3; exit}'
}

# Werte eines Arrays (z.B. ServerAddresses) aus einem SystemConfiguration-Key.
sc_array() {
  printf 'show %s\n' "$1" | /usr/sbin/scutil \
    | /usr/bin/awk -v k="$2" '$1 == k {f = 1; next} f && /}/ {f = 0} f {print $3}'
}

# Je Altlast eine Zeile "dns <utunN>": vom vpnc-script angelegte
# Tunnel-Dienste, die auf thm.de verweisen und deren utun-Interface nicht mehr
# existiert. Das Interface verschwindet mit dem Prozess, der es geoeffnet hat;
# lebt es noch, gehoert der Eintrag einem aktiven VPN (z.B. Cisco Secure Client).
# Da utun-Nummern neu vergeben werden, zaehlt ein existierendes Interface nur,
# wenn es auch die im IPv4-Key eingetragene Tunnel-Adresse traegt.
find_stale_dns() {
  local svc utun addr
  for svc in $(printf 'list State:/Network/Service/utun[0-9]+/DNS\n' | /usr/sbin/scutil \
                 | /usr/bin/awk '{print $4}'); do
    utun=${svc#State:/Network/Service/}
    utun=${utun%/DNS}
    if /sbin/ifconfig "$utun" >/dev/null 2>&1; then
      addr=$(sc_array "State:/Network/Service/$utun/IPv4" Addresses | /usr/bin/head -n 1)
      [ -z "$addr" ] || /sbin/ifconfig "$utun" | /usr/bin/grep -qF "inet $addr " && continue
    fi
    printf 'show %s\n' "$svc" | /usr/sbin/scutil | /usr/bin/grep -q ': thm\.de$' || continue
    echo "dns $utun"
  done
}

# Statische Host-Routen ueber ein Gateway (Flags U,G,H,S) - so legt das
# vpnc-script die Route zum VPN-Gateway an.
static_host_routes() {
  /usr/sbin/netstat -rn -f inet \
    | /usr/bin/awk '$3 ~ /G/ && $3 ~ /H/ && $3 ~ /S/ {print $1}'
}

# Je Altlast eine Zeile "route <ip>": statische Host-Route zum Gateway.
# Gibt es keine solche Route, entfaellt die DNS-Abfrage ganz (das Plugin
# ruft --check alle 10 s auf).
find_stale_routes() {
  local hosts ip
  hosts=$(static_host_routes)
  [ -n "$hosts" ] || return 0
  for ip in $(gateway_ips); do
    printf '%s\n' "$hosts" | /usr/bin/grep -qxF "$ip" && echo "route $ip"
  done
  return 0
}

# Gibt es eine allgemeine (nicht an ein Interface gebundene, Flag I) Default-Route?
has_default_route() {
  /usr/sbin/netstat -rn -f inet | /usr/bin/awk '$1 == "default" && $3 !~ /I/ {f = 1} END {exit !f}'
}

# Dateien des vpnc-script (defaultroute.<pid>, resolv.conf-backup.<pid> ...),
# deren Prozess nicht mehr laeuft.
stale_vpnc_files() {
  local f pid
  for f in /var/run/vpnc/*.[0-9]*; do
    [ -f "$f" ] || continue
    pid=${f##*.}
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    /bin/ps -p "$pid" >/dev/null 2>&1 && continue
    echo "$f"
  done
}

# Zeile "default <gw>", wenn die allgemeine Default-Route fehlt und eine
# verwaiste defaultroute-Datei zeigt, dass das vpnc-script sie ersetzt hatte
# (ohne diese Datei ist man schlicht offline - kein Fall fuers Aufraeumen).
find_stale_default() {
  has_default_route && return 0
  local f gw
  for f in $(stale_vpnc_files); do
    case "$f" in
      */defaultroute.*)
        gw=$(/usr/bin/head -n 1 "$f")
        echo "default ${gw:-?}"
        return 0
        ;;
    esac
  done
  return 0
}

# Gibt je Altlast eine Zeile "default <gw>", "route <ip>" bzw. "dns <utunN>" aus.
# Solange ein alter THM-DNS-Eintrag existiert, laeuft die Aufloesung von
# vpn.thm.de ins Leere (THM-Nameserver ohne Tunnel unerreichbar) - dann
# wird die Route nicht geprueft; cleanup() holt das nach Entfernen des DNS nach.
find_stale() {
  vpn_active && return
  find_stale_default
  local dns
  dns=$(find_stale_dns)
  if [ -n "$dns" ]; then
    echo "$dns"
  else
    find_stale_routes
  fi
}

# Das vpnc-script setzt die THM-Nameserver zusaetzlich dauerhaft am aktiven
# Netzwerkdienst (networksetup -setdnsservers); nur der saubere Abbau nimmt
# das zurueck. Dienste, deren DNS-Server genau einer der alten Tunnel-
# Nameserver ist, werden auf automatisch (Empty) zurueckgesetzt.
reset_service_dns() {
  local servers="$1" svc
  [ -n "$servers" ] || return 0
  while IFS= read -r svc; do
    /usr/sbin/networksetup -getdnsservers "$svc" 2>/dev/null \
      | /usr/bin/grep -qxF "$servers" || continue
    echo "    Setze DNS-Server von \"$svc\" zurueck"
    /usr/sbin/networksetup -setdnsservers "$svc" Empty
  done < <(/usr/sbin/networksetup -listallnetworkservices | /usr/bin/tail -n +2 \
             | /usr/bin/sed 's/^\*//')
}

# Liegt ein Gateway direkt im lokalen Netz eines physischen Interfaces?
# (route get liefert dann keine gateway-Zeile.) Schuetzt davor, nach einem
# Netzwechsel ein Gateway einzutragen, das es hier nicht gibt.
gateway_on_link() {
  local out
  [[ "$1" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  out=$(/sbin/route -n get "$1" 2>/dev/null) || return 1
  echo "$out" | /usr/bin/grep -q 'gateway:' && return 1
  echo "$out" | /usr/bin/grep -qE 'interface: (en|bridge)[0-9]+'
}

# Stellt die allgemeine Default-Route wieder her. Meist erledigt das macOS
# selbst, sobald der Tunnel-Key mit OverridePrimary entfernt ist; sonst wird
# der aktuelle Router des primaeren Dienstes eingetragen, ersatzweise das vom
# vpnc-script gesicherte Gateway - jeweils nur, wenn es direkt erreichbar ist.
restore_default_route() {
  local saved="$1" gw
  for _ in 0 1 2 3; do
    [ "$_" -gt 0 ] && sleep 1
    has_default_route && { echo "    Default-Route von macOS wiederhergestellt"; return 0; }
  done
  for gw in "$(sc_value State:/Network/Global/IPv4 Router)" "$saved"; do
    gateway_on_link "$gw" || continue
    echo "    Setze Default-Route ueber $gw"
    /sbin/route -n add default "$gw" >/dev/null && return 0
  done
  echo "    Keine Default-Route - WLAN bzw. Netzwerk einmal aus- und wieder einschalten."
  return 1
}

cleanup() {
  local kind what n=0 default
  if vpn_active; then
    echo "==> VPN ist noch aktiv - nichts angefasst."
    return
  fi
  # Vorher festhalten: Nach Entfernen des Tunnel-Keys setzt macOS die
  # Default-Route meist sofort selbst.
  default=$(find_stale_default)
  # Erst DNS entfernen, damit danach das Gateway wieder aufgeloest werden kann.
  while read -r kind what; do
    [[ "$what" =~ ^utun[0-9]+$ ]] || continue
    echo "    Entferne DNS-Eintrag von $what"
    reset_service_dns "$(sc_array "State:/Network/Service/$what/DNS" ServerAddresses)"
    printf 'remove State:/Network/Service/%s/IPv4\nremove State:/Network/Service/%s/DNS\n' \
      "$what" "$what" | /usr/sbin/scutil && n=$((n + 1))
  done < <(find_stale_dns)
  if [ "$n" -gt 0 ]; then
    /usr/bin/dscacheutil -flushcache
    /usr/bin/killall -HUP mDNSResponder 2>/dev/null
  fi
  # Default-Route vor der Gateway-Aufloesung: ohne sie ist kein Nameserver erreichbar.
  if [ -n "$default" ]; then
    restore_default_route "${default#default }" && n=$((n + 1))
  fi
  for what in $(stale_vpnc_files); do
    echo "    Entferne $what"
    /bin/rm -f -- "$what"
  done
  if [ "$n" -gt 0 ]; then
    # mDNSResponder uebernimmt die neue Resolver-Konfiguration asynchron:
    # Gibt es eine Kandidaten-Route, kurz warten, bis das Gateway aufloest.
    if [ -n "$(static_host_routes)" ]; then
      for _ in 1 2 3 4 5; do
        [ -n "$(gateway_ips)" ] && break
        sleep 1
      done
    fi
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
if vpn_active; then
  /usr/bin/osascript -e 'display notification "VPN ist noch aktiv - erst trennen." with title "THM-VPN aufraeumen"'
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
