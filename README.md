# THM-VPN mit openconnect + Statusanzeige in der Menüleiste

VPN-Zugang zur **THM (Technische Hochschule Mittelhessen)** über die Kommandozeile mit
[`openconnect`](https://www.infradead.org/openconnect/) statt des Cisco Secure Client /
AnyConnect – plus eine kleine **Statusanzeige in der macOS-Menüleiste** über
[SwiftBar](https://github.com/swiftbar/SwiftBar), inklusive Knopf zum sauberen Trennen.

```
🔒 THM      ← verbunden (Dropdown zeigt Tunnel-IP + "VPN trennen")
🔓          ← getrennt
```

Getestet auf macOS (Apple Silicon) mit openconnect 9.12 und SwiftBar 2.0.

---

## Warum?

Der Cisco Secure Client ist ein schwergewichtiger Hintergrunddienst. `openconnect` ist ein
schlanker Open-Source-Client, der dasselbe AnyConnect-Protokoll spricht und sich komplett
über die Kommandozeile steuern lässt. Einziger Nachteil gegenüber dem Cisco-Client: Es gibt
**kein Menüleisten-Symbol**, das anzeigt, ob man verbunden ist – das natürliche macOS-VPN-Symbol
(Kontrollzentrum → VPN) erfasst `openconnect` nicht, weil es ein User-Space-Tunnel über `utun`
ist. Diese Lücke schließt das SwiftBar-Plugin in diesem Repo.

---

## Teil 1 – VPN mit openconnect

### Installation

```bash
brew install openconnect
```

### Verbinden

```bash
sudo openconnect --protocol=anyconnect --user=<rz-kennung> vpn.thm.de
```

`<rz-kennung>` durch die eigene THM-Kennung ersetzen (z. B. `clucke`). Der Befehl fragt
interaktiv nach dem macOS-`sudo`-Passwort und anschließend nach dem VPN-Passwort (ggf. zweiter
Faktor). Der Tunnel bleibt **im Vordergrund** geöffnet – zum Trennen `Strg-C` drücken.

Tipp: In einem eigenen Terminal-Tab oder in einer `tmux`-Session laufen lassen, damit das
Fenster nicht im Weg ist:

```bash
tmux new -s vpnterm
sudo openconnect --protocol=anyconnect --user=<rz-kennung> vpn.thm.de
# Ablösen mit  Strg-b d  ,  zurück mit  tmux attach -t vpnterm
```

Falls beim Login eine **Gruppen-Auswahl** erscheint (wie das Dropdown im Cisco-Client), zeigt
openconnect die Optionen interaktiv an; den Namen kann man dann dauerhaft mit
`--authgroup=<name>` setzen.

> **Hinweis:** Cisco Secure Client und openconnect nicht **gleichzeitig** verbinden – beide
> wollen die Routing-Tabelle verwalten. Der Cisco-Hintergrunddienst (`vpnagentd`) darf laufen,
> solange keine aktive Cisco-Sitzung besteht.

### Der harmlose DNS-Fehlermeldung beim Verbinden

Direkt nach dem erfolgreichen Verbindungsaufbau erscheint sehr wahrscheinlich:

```
 is not a recognized network service.
** Error: The parameters were not valid.
```

**Das ist kosmetisch und kann ignoriert werden – VPN und DNS funktionieren trotzdem.**

Ursache: Das mitgelieferte `vpnc-script` (das openconnect nach dem Connect aufruft) versucht,
die VPN-DNS-Server zusätzlich per `networksetup` auf dem physischen Netzwerkdienst zu setzen.
Dazu liest es `route -n get default` – allerdings **nachdem** es die Default-Route bereits auf
den VPN-Tunnel (`utunN`) umgebogen hat. Es bekommt also `utunN` statt `en0`, und `utunN` ist
kein konfigurierbarer Netzwerkdienst → leerer Name → die Fehlermeldung. Beim Trennen erscheint
sie aus demselben Grund noch einmal.

Das DNS wird parallel bereits über den **sauberen** `scutil`-Mechanismus korrekt gesetzt. Prüfen:

```bash
scutil --dns | head           # resolver #1 sollte die THM-Nameserver + Such-Domain thm.de zeigen
nslookup vpn.thm.de           # interne Auflösung muss klappen
```

Bei der THM sind das die Nameserver `192.168.186.83` / `192.168.185.83` mit Such-Domain `thm.de`.
Solange die hier auftauchen, ist alles gut.

---

## Teil 2 – Statusanzeige in der Menüleiste (SwiftBar)

### Schnellinstallation

```bash
git clone https://github.com/carstenlucke/thm-vpn-swiftbar.git
cd thm-vpn-swiftbar
./install.sh
```

`install.sh` installiert bei Bedarf `openconnect` und `SwiftBar` via Homebrew, kopiert die
beiden Skripte nach `~/.config/swiftbar/`, setzt den SwiftBar-Plugin-Ordner und startet SwiftBar.

### Manuelle Installation

```bash
# SwiftBar installieren
brew install --cask swiftbar

# Skripte platzieren
mkdir -p ~/.config/swiftbar/plugins
cp plugins/thmvpn.10s.sh   ~/.config/swiftbar/plugins/
cp thmvpn-disconnect.sh    ~/.config/swiftbar/
chmod +x ~/.config/swiftbar/plugins/thmvpn.10s.sh ~/.config/swiftbar/thmvpn-disconnect.sh

# SwiftBar den Plugin-Ordner mitteilen und starten
defaults write com.ameba.SwiftBar PluginDirectory -string "$HOME/.config/swiftbar/plugins"
open -a SwiftBar
```

### Autostart

Damit das Symbol nach einem Neustart automatisch erscheint: im SwiftBar-Menü →
*Preferences* → **„Launch at Login"** aktivieren (in SwiftBar 2 nur über die App selbst möglich,
nicht per Kommandozeile).

---

## Wie funktioniert es?

**Statuserkennung** (`plugins/thmvpn.10s.sh`): Das Plugin prüft alle 10 Sekunden, ob eine
`utun`-Schnittstelle eine Adresse aus dem THM-VPN-Pool `10.196.x` trägt. Das Refresh-Intervall
steckt im Dateinamen (`…10s.sh`) – für 5 Sekunden einfach in `thmvpn.5s.sh` umbenennen.

**Trennen-Knopf** (`thmvpn-disconnect.sh`): `openconnect` läuft als `root` (per `sudo` gestartet),
ein SwiftBar-Plugin dagegen als normaler Benutzer und darf den Prozess nicht beenden. Der Helfer
nutzt daher `osascript … with administrator privileges` – das öffnet den **nativen
macOS-Passwortdialog** (kein dauerhafter Eingriff in `sudoers`) und beendet openconnect per
`SIGINT`. `SIGINT` ist wichtig: openconnect räumt dann sauber auf und das `vpnc-script` setzt
Routen und DNS zurück (so, als hätte man im Terminal `Strg-C` gedrückt).

---

## Optional: Trennen ohne Passwortdialog

Wer den Passwortdialog beim Trennen loswerden will, kann einen eng begrenzten `sudoers`-Eintrag
anlegen. **Sicherheitsabwägung:** Damit darf der eigene Benutzer openconnect ohne Passwort
beenden – das ist unkritisch (nur ein gezieltes Signal an einen Prozess), aber eine bewusste
Änderung an der Systemkonfiguration.

```bash
# Datei sicher mit visudo anlegen (Syntaxprüfung):
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pkill -INT openconnect" | \
  sudo tee /etc/sudoers.d/openconnect-disconnect
sudo chmod 440 /etc/sudoers.d/openconnect-disconnect
```

Anschließend in `thmvpn-disconnect.sh` die `osascript`-Zeile ersetzen durch:

```bash
/usr/bin/sudo /usr/bin/pkill -INT openconnect
```

---

## Deinstallation

```bash
rm -f ~/.config/swiftbar/plugins/thmvpn.10s.sh ~/.config/swiftbar/thmvpn-disconnect.sh
# optional:
brew uninstall --cask swiftbar
brew uninstall openconnect
sudo rm -f /etc/sudoers.d/openconnect-disconnect   # falls angelegt
```

---

## Dateien

| Datei | Zweck |
|-------|-------|
| `plugins/thmvpn.10s.sh` | SwiftBar-Plugin: zeigt Status + Trennen-Knopf, Refresh alle 10 s |
| `thmvpn-disconnect.sh`  | Helfer: beendet openconnect sauber (per Admin-Dialog) |
| `install.sh`            | Einrichtung in einem Schritt |
