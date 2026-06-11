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
cp "$REPO_DIR/thmvpn-connect.sh"    "$SWIFTBAR_DIR/thmvpn-connect.sh"
chmod +x "$PLUGIN_DIR/thmvpn.10s.sh" "$SWIFTBAR_DIR/thmvpn-disconnect.sh" "$SWIFTBAR_DIR/thmvpn-connect.sh"

# Config-Vorlage anlegen, vorhandene Konfiguration nicht ueberschreiben
if [ ! -f "$SWIFTBAR_DIR/thmvpn.conf" ]; then
  cp "$REPO_DIR/thmvpn.conf.example" "$SWIFTBAR_DIR/thmvpn.conf"
  echo "    Konfigvorlage angelegt: $SWIFTBAR_DIR/thmvpn.conf (RZ-Kennung dort eintragen)"
else
  echo "    Bestehende Konfiguration beibehalten: $SWIFTBAR_DIR/thmvpn.conf"
fi

echo "==> SwiftBar-Plugin-Ordner setzen"
defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"

echo "==> SwiftBar starten / neu laden"
open -a SwiftBar
open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true

echo "==> Optional: Trennen ohne Passwortdialog"
SUDOERS_FILE="/etc/sudoers.d/openconnect-disconnect"
if [ -f "$SUDOERS_FILE" ]; then
  echo "    sudoers-Eintrag bereits vorhanden -> uebersprungen ($SUDOERS_FILE)."
else
  echo "    Damit der 'VPN trennen'-Knopf openconnect ohne Passwortdialog beenden kann,"
  echo "    laesst sich ein eng begrenzter sudoers-Eintrag anlegen:"
  echo "      $(whoami) ALL=(root) NOPASSWD: /usr/bin/pkill -INT openconnect"
  echo "    (Nur ein gezieltes Signal an openconnect - keine weiteren Rechte.)"
  printf "    Jetzt anlegen? Erfordert dein sudo-Passwort. [j/N] "
  read -r ANSWER || ANSWER=""
  case "$ANSWER" in
    j|J|y|Y)
      TMP_SUDOERS="$(mktemp)"
      echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pkill -INT openconnect" > "$TMP_SUDOERS"
      if sudo visudo -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
        sudo install -m 440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS_FILE"
        echo "    Angelegt: $SUDOERS_FILE"
      else
        echo "    FEHLER: sudoers-Syntaxpruefung fehlgeschlagen - nichts geaendert." >&2
      fi
      rm -f "$TMP_SUDOERS"
      ;;
    *)
      echo "    Uebersprungen. (Standard: nativer Passwortdialog beim Trennen.)"
      ;;
  esac
fi

echo
echo "Fertig. In der Menueleiste erscheint:"
echo "  🔒 THM  - VPN verbunden (mit 'VPN trennen' im Dropdown)"
echo "  🔓      - VPN getrennt  (mit 'VPN verbinden' im Dropdown)"
echo
echo "Verbinden geht jetzt per Menue ('VPN verbinden' oeffnet ein Terminal)"
echo "oder manuell:  sudo openconnect --protocol=anyconnect --user=<rz-kennung> vpn.thm.de"
