#!/bin/bash
# <xbar.title>THM VPN Status</xbar.title>
# <xbar.version>v1.2.0</xbar.version>
# <xbar.author>Carsten Lucke</xbar.author>
# <xbar.desc>Zeigt in der Menueleiste an, ob openconnect mit dem THM-VPN (Netz 10.196.x) verbunden ist, inkl. Verbinden- und Trennen-Knopf sowie Health-Check fuer Reste abgebrochener Sitzungen.</xbar.desc>
#
# Der Dateiname steuert das Refresh-Intervall: thmvpn.10s.sh = alle 10 Sekunden.
# Liegt nach der Installation in ~/.config/swiftbar/plugins/

DISCONNECT="$HOME/.config/swiftbar/thmvpn-disconnect.sh"
CONNECT="$HOME/.config/swiftbar/thmvpn-connect.sh"
CLEANUP="$HOME/.config/swiftbar/thmvpn-cleanup.sh"

if /sbin/ifconfig | grep -q "inet 10.196"; then
  IP=$(/sbin/ifconfig | awk '/inet 10.196/ {print $2; exit}')
  echo "🔒 THM"
  echo "---"
  echo "VPN verbunden | color=#2da44e"
  echo "Tunnel-IP: ${IP} | font=Menlo size=12"
  echo "---"
  echo "VPN trennen | shell=\"$DISCONNECT\" terminal=false refresh=true color=#cf222e"
else
  # Health-Check: Reste einer nicht sauber beendeten Sitzung (Route, DNS,
  # Default-Route)? Das Warnsymbol nur bei Resten, die auch ohne VPN stoeren:
  # DNS (thm.de-Namen loesen nicht auf) und fehlende Default-Route (kein
  # Internet). Eine alte Gateway-Route stoert nur beim Verbinden, und
  # "VPN verbinden" raeumt sie ohnehin vorher weg.
  STALE=$("$CLEANUP" --check 2>/dev/null)
  if echo "$STALE" | grep -qE '^(dns|default) '; then
    echo "🔓⚠️"
  else
    echo "🔓"
  fi
  echo "---"
  echo "VPN getrennt | color=#888888"
  if [ -n "$STALE" ]; then
    echo "---"
    echo "Reste der letzten VPN-Sitzung | color=#bf8700"
    echo "$STALE" | while read -r KIND WHAT; do
      case "$KIND" in
        route) echo "Alte Route zu $WHAT (wird beim Verbinden entfernt) | font=Menlo size=12" ;;
        dns)   echo "Alter THM-DNS auf $WHAT | font=Menlo size=12" ;;
        default) echo "Default-Route fehlt (vorher über $WHAT) | font=Menlo size=12" ;;
      esac
    done
    echo "Aufräumen | shell=\"$CLEANUP\" terminal=false refresh=true color=#bf8700"
  fi
  echo "---"
  echo "VPN verbinden | shell=\"$CONNECT\" terminal=false refresh=true color=#2da44e"
fi
