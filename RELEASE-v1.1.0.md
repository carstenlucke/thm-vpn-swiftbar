# Release v1.1.0

Diese Version macht die THM-VPN-Statusanzeige zur **vollständigen Steuerung aus der Menüleiste**:
Die Verbindung lässt sich jetzt auch direkt aus dem Menü **aufbauen** (bisher nur trennen), und
die Anmeldung kommt mit **Touch ID** statt getippter Passwörter aus.

## Highlights

- 🔌 **Verbinden per Menüleiste.** Im getrennten Zustand bietet das Dropdown jetzt „VPN verbinden" –
  ein Klick öffnet ein Terminal und baut die Verbindung auf. Das Symbol springt anschließend
  automatisch auf 🔒.
- 👆 **Touch ID statt Passwort.** Mit Touch ID für `sudo` genügt beim Verbinden der Fingerabdruck,
  sodass nur noch das VPN-Kennwort zu tippen ist – und auch das Trennen lässt sich per Touch ID
  bestätigen.
- ⚙️ **Konfigurationsdatei.** RZ-Kennung, Gateway und Login-Gruppe werden einmalig in
  `thmvpn.conf` hinterlegt, statt sie bei jedem Verbinden anzugeben.

## Verbinden per Menüleiste

- Neuer Menüpunkt **„VPN verbinden"** im getrennten Zustand: öffnet ein Terminal-Fenster und
  startet `openconnect`. Dort gibst du die Passwörter ein (inkl. eventuellem zweitem Faktor); die
  Statusanzeige wechselt nach spätestens 10 Sekunden auf „verbunden".
- **Einmalige Konfiguration** über `~/.config/swiftbar/thmvpn.conf`: RZ-Kennung (`THM_USER`),
  Gateway (`THM_HOST`, Standard `vpn.thm.de`) und optional die Login-Gruppe (`THM_AUTHGROUP`).
  Ohne hinterlegte Kennung fragt `openconnect` interaktiv nach dem Benutzernamen.

## Anmeldung mit Touch ID

- **Beim Verbinden** genügt mit aktiviertem Touch ID für `sudo` der Fingerabdruck für die
  Administrator-Berechtigung – danach bleibt nur das VPN-Kennwort zum Tippen.
- **Beim Trennen** wählt der Helfer den Weg zur Bestätigung automatisch: per Touch ID, per
  passwortlosem Eintrag oder per Passwortdialog – je nachdem, was eingerichtet ist.
- Aus Sicherheitsgründen wird bewusst **nicht** empfohlen, `openconnect` selbst ohne Passwort
  freizugeben; Touch ID bietet denselben Komfort, ohne die Berechtigungsgrenze aufzuweichen.

## Trennen

- Das Trennen erkennt den passenden Weg **automatisch** – komplett bestätigungsfrei (optionaler
  `sudoers`-Eintrag), per Touch ID oder per nativem Admin-Dialog. Ein manuelles Anpassen des
  Skripts ist nicht nötig.
- Wer **komplett bestätigungsfrei** trennen möchte, kann einen eng begrenzten `sudoers`-Eintrag
  anlegen. Die Einrichtung bietet `install.sh` jetzt auf Wunsch direkt an (mit Syntaxprüfung), und
  das Plugin erkennt den Eintrag selbsttätig.

## Installation

- `install.sh` richtet jetzt auch den **Verbinden-Helfer** und eine **Konfigurationsvorlage** ein
  und fragt optional nach dem passwortlosen `sudoers`-Eintrag fürs Trennen.
- Eine bestehende `thmvpn.conf` bleibt bei erneuter Installation unangetastet.

## Dokumentation

- Die README wurde um die Abschnitte **„Verbinden per Menü"**, **Touch ID für `sudo`** und die
  **Konfiguration** erweitert; Deinstallation und Dateiübersicht sind entsprechend aktualisiert.

---

*Getestet auf macOS (Apple Silicon) mit openconnect 9.12 und SwiftBar 2.0.*
