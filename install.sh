#!/usr/bin/env bash
set -euo pipefail

# Installiert die THM-VPN-Statusanzeige fuer SwiftBar:
#   - prueft/installiert openconnect + SwiftBar via Homebrew
#   - kopiert Plugin + Disconnect-Helfer nach ~/.config/swiftbar
#   - setzt den SwiftBar-Plugin-Ordner und startet SwiftBar
#
# Aufruf:  ./install.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFTBAR_DIR="$HOME/.config/swiftbar"
PLUGIN_DIR="$SWIFTBAR_DIR/plugins"

echo "==> Homebrew-Pakete pruefen"
if ! command -v brew >/dev/null; then
  echo "FEHLER: Homebrew ist nicht installiert -> https://brew.sh" >&2
  exit 1
fi
command -v openconnect >/dev/null || brew install openconnect
[ -d "/Applications/SwiftBar.app" ] || brew install --cask swiftbar

echo "==> Skripte installieren nach $SWIFTBAR_DIR"
mkdir -p "$PLUGIN_DIR"
cp "$REPO_DIR/plugins/thmvpn.10s.sh" "$PLUGIN_DIR/thmvpn.10s.sh"
cp "$REPO_DIR/thmvpn-disconnect.sh" "$SWIFTBAR_DIR/thmvpn-disconnect.sh"
chmod +x "$PLUGIN_DIR/thmvpn.10s.sh" "$SWIFTBAR_DIR/thmvpn-disconnect.sh"

echo "==> SwiftBar-Plugin-Ordner setzen"
defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"

echo "==> SwiftBar starten / neu laden"
open -a SwiftBar
open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true

echo
echo "Fertig. In der Menueleiste erscheint:"
echo "  🔒 THM  - VPN verbunden (mit 'VPN trennen' im Dropdown)"
echo "  🔓      - VPN getrennt"
echo
echo "Verbinden:  sudo openconnect --protocol=anyconnect --user=<rz-kennung> vpn.thm.de"
