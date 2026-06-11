# Release v1.0.0

Erste öffentliche Version von **THM-VPN mit openconnect + Statusanzeige in der Menüleiste**.

Das Projekt ermöglicht den VPN-Zugang zur THM (Technische Hochschule Mittelhessen) über
[`openconnect`](https://www.infradead.org/openconnect/) statt des schwergewichtigen Cisco Secure
Client – ergänzt um eine schlanke Statusanzeige in der macOS-Menüleiste über
[SwiftBar](https://github.com/swiftbar/SwiftBar).

## Highlights

- 🔒 **Menüleisten-Statusanzeige für openconnect.** Schließt die zentrale Lücke gegenüber dem
  Cisco-Client: Ein Symbol in der Menüleiste zeigt jederzeit, ob die THM-VPN-Verbindung aktiv
  ist (🔒 THM) oder nicht (🔓). Das native macOS-VPN-Symbol erfasst openconnect nicht, da es ein
  User-Space-Tunnel über `utun` ist.
- 🔌 **Sauberer Trennen-Knopf direkt im Menü.** Über das Dropdown lässt sich die Verbindung mit
  einem Klick beenden – inklusive korrektem Zurücksetzen von Routen und DNS.
- ⚡ **Einrichtung in einem Schritt.** Ein einziges Installationsskript bringt alle Komponenten
  in Stellung.

## Funktionen

- **Live-Statuserkennung:** Die Verbindung wird alle 10 Sekunden geprüft, indem nach einer
  `utun`-Schnittstelle mit einer Adresse aus dem THM-VPN-Pool gesucht wird. Das Symbol zeigt den
  aktuellen Zustand und im verbundenen Fall die Tunnel-IP an. Das Aktualisierungsintervall lässt
  sich durch einfaches Umbenennen der Plugin-Datei anpassen (z. B. auf 5 Sekunden).
- **Verbindung sauber trennen:** Der Trennen-Helfer beendet openconnect per `SIGINT`, sodass das
  `vpnc-script` Routen und DNS wieder zurücksetzt – genau so, als hätte man im Terminal `Strg-C`
  gedrückt. Da openconnect als `root` läuft, öffnet sich dafür der native macOS-Passwortdialog;
  es ist kein dauerhafter Eingriff in `sudoers` nötig.
- **Optionales Trennen ohne Passwortdialog:** Für Komfort lässt sich ein eng begrenzter
  `sudoers`-Eintrag anlegen, der das Beenden ohne Passwortabfrage erlaubt – mit transparenter
  Erläuterung der Sicherheitsabwägung.

## Installation

- **Ein-Schritt-Installation** über `install.sh`: prüft und installiert bei Bedarf `openconnect`
  und `SwiftBar` via Homebrew, kopiert die Skripte nach `~/.config/swiftbar/`, setzt den
  SwiftBar-Plugin-Ordner und startet SwiftBar.
- **Manuelle Installation** mit nachvollziehbaren Einzelschritten für alle, die mehr Kontrolle
  möchten.
- **Autostart-Hinweis** zum automatischen Anzeigen des Symbols nach einem Neustart.
- **Saubere Deinstallation** mit klaren Schritten zum vollständigen Entfernen aller Komponenten.

## Dokumentation

- Ausführliche README auf Deutsch mit Schritt-für-Schritt-Anleitung zum Verbinden via
  openconnect (inkl. Hinweisen zu `sudo`, zweitem Faktor, Gruppen-Auswahl und `tmux`).
- Erklärung der **harmlosen DNS-Fehlermeldung** beim Verbinden und Trennen samt Ursache und
  Prüfbefehlen (`scutil --dns`, `nslookup`), damit der kosmetische Fehler nicht verunsichert.
- Hintergrundabschnitt „Wie funktioniert es?", der Statuserkennung und Trennen-Mechanik
  verständlich beschreibt.
- Wichtiger Hinweis, Cisco Secure Client und openconnect nicht gleichzeitig zu verbinden.

---

*Getestet auf macOS (Apple Silicon) mit openconnect 9.12 und SwiftBar 2.0.*
