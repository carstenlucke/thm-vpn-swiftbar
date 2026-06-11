#!/bin/bash
# <xbar.title>THM VPN Status</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>Carsten Lucke</xbar.author>
# <xbar.desc>Zeigt in der Menueleiste an, ob openconnect mit dem THM-VPN (Netz 10.196.x) verbunden ist, inkl. Trennen-Knopf.</xbar.desc>
#
# Der Dateiname steuert das Refresh-Intervall: thmvpn.10s.sh = alle 10 Sekunden.
# Liegt nach der Installation in ~/.config/swiftbar/plugins/

DISCONNECT="$HOME/.config/swiftbar/thmvpn-disconnect.sh"

if /sbin/ifconfig | grep -q "inet 10.196"; then
  IP=$(/sbin/ifconfig | awk '/inet 10.196/ {print $2; exit}')
  echo "🔒 THM"
  echo "---"
  echo "VPN verbunden | color=#2da44e"
  echo "Tunnel-IP: ${IP} | font=Menlo size=12"
  echo "---"
  echo "VPN trennen | shell=\"$DISCONNECT\" terminal=false refresh=true color=#cf222e"
else
  echo "🔓"
  echo "---"
  echo "VPN getrennt | color=#888888"
fi
