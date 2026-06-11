# THM-VPN mit openconnect + Statusanzeige in der Menüleiste

VPN-Zugang zur **THM (Technische Hochschule Mittelhessen)** über die Kommandozeile mit
[`openconnect`](https://www.infradead.org/openconnect/) statt des Cisco Secure Client /
AnyConnect – plus eine kleine **Statusanzeige in der macOS-Menüleiste** über
[SwiftBar](https://github.com/swiftbar/SwiftBar), inklusive Knopf zum sauberen Trennen.

```
🔒 THM      ← verbunden (Dropdown zeigt Tunnel-IP + "VPN trennen")
🔓          ← getrennt (Dropdown zeigt "VPN verbinden")
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

`<rz-kennung>` durch die eigene THM-Kennung ersetzen (z. B. `johndoe`). Der Befehl fragt
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
Skripte und eine Konfig-Vorlage nach `~/.config/swiftbar/`, setzt den SwiftBar-Plugin-Ordner und
startet SwiftBar.

### Manuelle Installation

```bash
# SwiftBar installieren
brew install --cask swiftbar

# Skripte platzieren
mkdir -p ~/.config/swiftbar/plugins
cp plugins/thmvpn.10s.sh   ~/.config/swiftbar/plugins/
cp thmvpn-disconnect.sh    ~/.config/swiftbar/
cp thmvpn-connect.sh       ~/.config/swiftbar/
chmod +x ~/.config/swiftbar/plugins/thmvpn.10s.sh \
         ~/.config/swiftbar/thmvpn-disconnect.sh \
         ~/.config/swiftbar/thmvpn-connect.sh

# Konfig-Vorlage anlegen (RZ-Kennung dort eintragen)
cp thmvpn.conf.example     ~/.config/swiftbar/thmvpn.conf

# SwiftBar den Plugin-Ordner mitteilen und starten
defaults write com.ameba.SwiftBar PluginDirectory -string "$HOME/.config/swiftbar/plugins"
open -a SwiftBar
```

### Autostart

Damit das Symbol nach einem Neustart automatisch erscheint: im SwiftBar-Menü →
*Preferences* → **„Launch at Login"** aktivieren (in SwiftBar 2 nur über die App selbst möglich,
nicht per Kommandozeile).

### Verbinden per Menü

Im getrennten Zustand bietet das Dropdown **„VPN verbinden"**. Da `openconnect` interaktiv nach
sudo- und VPN-Passwort (und ggf. zweitem Faktor) fragt und im Vordergrund laufen muss, öffnet
dieser Menüpunkt ein **Terminal-Fenster** und startet dort `openconnect`. Passwörter eingeben –
das Symbol springt nach spätestens 10 s auf 🔒. Zum Trennen `Strg-C` im Fenster oder den
Menüpunkt „VPN trennen".

Die RZ-Kennung (und optional Gateway/Gruppe) liest `thmvpn-connect.sh` aus
`~/.config/swiftbar/thmvpn.conf`:

```bash
THM_USER=<rz-kennung>     # weglassen -> openconnect fragt interaktiv nach dem Benutzernamen
#THM_HOST=vpn.thm.de      # Standard
#THM_AUTHGROUP=<gruppe>   # nur falls beim Login eine Gruppe gewählt werden muss
```

#### Nur das VPN-Kennwort tippen: Touch ID für `sudo`

`openconnect` braucht `root`, fragt also zuerst nach dem `sudo`-Passwort und danach nach dem
VPN-Kennwort. Wer sich das `sudo`-Passwort sparen will, aktiviert **Touch ID für `sudo`** – dann
genügt der Fingerabdruck und es bleibt nur das VPN-Kennwort zum Tippen:

```bash
# Update-fest über sudo_local (überschreibt keine System-Datei):
sudo sh -c "sed 's/^#auth/auth/' /etc/pam.d/sudo_local.template > /etc/pam.d/sudo_local"
```

> **Warum nicht `sudo openconnect` per `sudoers` freigeben?** Anders als beim Trennen
> (`/usr/bin/pkill`, SIP-geschützt) liegt die `openconnect`-Binary unter Homebrew in einem
> **dir gehörenden** Verzeichnis und lässt sich per `--script` zum Ausführen beliebigen Codes
> bewegen. Eine `NOPASSWD`-Regel darauf käme faktisch passwortlosem `root` gleich – Touch ID ist
> der sichere Weg zum selben Komfort.

---

## Wie funktioniert es?

**Statuserkennung** (`plugins/thmvpn.10s.sh`): Das Plugin prüft alle 10 Sekunden, ob eine
`utun`-Schnittstelle eine Adresse aus dem THM-VPN-Pool `10.196.x` trägt. Das Refresh-Intervall
steckt im Dateinamen (`…10s.sh`) – für 5 Sekunden einfach in `thmvpn.5s.sh` umbenennen.

**Verbinden-Knopf** (`thmvpn-connect.sh`): Da der Verbindungsaufbau interaktiv ist und
`openconnect` im Vordergrund laufen muss, lässt sich das nicht geräuschlos im Hintergrund
erledigen. SwiftBar startet das Skript im Hintergrund; erkennt es, dass es ohne Terminal läuft
(`[ ! -t 0 ]`), startet es sich per `open -a Terminal` selbst in einem Fenster neu und ruft dort
`openconnect` mit den Werten aus `thmvpn.conf` auf. Das ist robuster als SwiftBars `terminal=true`,
das eine Automations-Freigabe für Terminal.app benötigen würde.

**Trennen-Knopf** (`thmvpn-disconnect.sh`): `openconnect` läuft als `root` (per `sudo` gestartet),
ein SwiftBar-Plugin dagegen als normaler Benutzer und darf den Prozess nicht beenden. Der Helfer
nutzt daher `osascript … with administrator privileges` – das öffnet den **nativen
macOS-Authentifizierungsdialog** (Touch ID oder Passwort, kein dauerhafter Eingriff in `sudoers`)
und beendet openconnect per `SIGINT`. `SIGINT` ist wichtig: openconnect räumt dann sauber auf und das `vpnc-script` setzt
Routen und DNS zurück (so, als hätte man im Terminal `Strg-C` gedrückt). Liegt der optionale
`sudoers`-Eintrag (siehe unten) vor, nutzt der Helfer stattdessen passwortloses `sudo` und der
Dialog entfällt.

---

## Optional: Trennen ohne Passwortdialog

Standardmäßig öffnet der „VPN trennen"-Knopf einen nativen macOS-Authentifizierungsdialog – auf
einem Mac mit **Touch ID genügt dort der Fingerabdruck** (ohne weitere Einrichtung). Wer auch
diese Bestätigung noch loswerden, also komplett bestätigungsfrei trennen will, kann einen eng
begrenzten `sudoers`-Eintrag anlegen. **Sicherheitsabwägung:** Damit darf der eigene Benutzer
openconnect ohne Passwort beenden – das ist unkritisch (nur ein gezieltes Signal an einen
Prozess), aber eine bewusste Änderung an der Systemkonfiguration.

`thmvpn-disconnect.sh` erkennt den Eintrag **automatisch**: Liegt
`/etc/sudoers.d/openconnect-disconnect` vor, wird passwortlos getrennt; sonst erscheint weiterhin
der Dialog. Ein manuelles Editieren des Skripts ist also nicht nötig.

Am einfachsten beim Setup: `install.sh` fragt am Ende, ob der Eintrag angelegt werden soll.
Manuell geht es so:

```bash
# Datei sicher mit visudo anlegen (Syntaxprüfung):
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pkill -INT openconnect" | \
  sudo tee /etc/sudoers.d/openconnect-disconnect
sudo chmod 440 /etc/sudoers.d/openconnect-disconnect
```

---

## Deinstallation

```bash
rm -f ~/.config/swiftbar/plugins/thmvpn.10s.sh \
      ~/.config/swiftbar/thmvpn-disconnect.sh \
      ~/.config/swiftbar/thmvpn-connect.sh \
      ~/.config/swiftbar/thmvpn.conf
# optional:
brew uninstall --cask swiftbar
brew uninstall openconnect
sudo rm -f /etc/sudoers.d/openconnect-disconnect   # falls angelegt
sudo rm -f /etc/pam.d/sudo_local                   # nur falls ausschließlich für Touch ID hier angelegt
```

---

## Dateien

| Datei | Zweck |
|-------|-------|
| `plugins/thmvpn.10s.sh` | SwiftBar-Plugin: zeigt Status + Verbinden-/Trennen-Knopf, Refresh alle 10 s |
| `thmvpn-connect.sh`     | Helfer: startet openconnect in einem Terminal (liest `thmvpn.conf`) |
| `thmvpn-disconnect.sh`  | Helfer: beendet openconnect sauber (per Admin-Dialog) |
| `thmvpn.conf.example`   | Vorlage für die Konfiguration (RZ-Kennung, Gateway, Gruppe) |
| `install.sh`            | Einrichtung in einem Schritt |
