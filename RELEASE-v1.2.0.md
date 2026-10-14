# Release v1.2.0

Diese Version macht die THM-VPN-Statusanzeige **robust gegen abgebrochene Sitzungen**: Endet
`openconnect` nicht sauber – durch Absturz, Ruhezustand, WLAN-Wechsel oder `kill -9` –, erkennt
das Plugin die zurückgebliebenen Reste und räumt sie auf Wunsch mit einem Klick auf. Bisher
blieben dann Namensauflösung, Internetzugang oder der nächste Verbindungsaufbau gestört, bis man
von Hand eingriff.

## Highlights

- 🩺 **Health-Check im getrennten Zustand.** Das Plugin prüft bei jedem Refresh, ob eine frühere
  Sitzung Reste hinterlassen hat, und listet die Funde im Dropdown. Stören sie auch ohne VPN,
  warnt das Symbol **🔓⚠️**.
- 🧹 **Aufräumen per Menüleiste.** Der neue Menüpunkt **„Aufräumen"** entfernt die Reste – die
  nötige Bestätigung erfolgt wie beim Trennen per Touch ID oder Admin-Dialog.
- 🔌 **Verbinden klappt wieder auf Anhieb.** „VPN verbinden" räumt vorher automatisch auf, sodass
  der Fehler *„Can't assign requested address"* nach einer abgebrochenen Sitzung nicht mehr
  auftritt.

## Health-Check und Aufräumen

- Erkannt und beseitigt werden die typischen Reste einer abgebrochenen Sitzung:
  - die **alte Route zum VPN-Gateway**, an der der nächste Verbindungsversuch scheitert,
  - die **THM-DNS-Einträge des Tunnels**, wegen derer `thm.de`-Namen ohne VPN nicht mehr
    auflösen – einschließlich der THM-Nameserver, die beim Verbinden am WLAN bzw. Netzwerkdienst
    eingetragen werden,
  - die **fehlende Default-Route** im Full-Tunnel-Betrieb, durch die nach einem Absturz gar kein
    Internet mehr erreichbar ist.
- Die Default-Route wird nur dann wiederhergestellt, wenn das Gateway direkt im aktuellen Netz
  liegt – nach einem Netzwechsel wird so kein falsches Gateway gesetzt. Im Zweifel genügt
  danach, das WLAN einmal aus- und wieder einzuschalten.
- Das Warnsymbol erscheint nur bei Resten, die auch ohne VPN stören (DNS, Default-Route). Eine
  alte Gateway-Route allein wird im Dropdown angezeigt, beim nächsten Verbinden aber ohnehin
  automatisch entfernt.
- **Aktive Verbindungen bleiben unangetastet:** Solange `openconnect` oder ein anderer
  THM-VPN-Client (z. B. Cisco Secure Client) verbunden ist, gilt nichts als Rest. Auch Einträge
  anderer aktiver VPN-Tunnel werden zuverlässig von Altlasten unterschieden.
- Der Check läuft ohne Administratorrechte und kommt im Normalfall ohne Netzwerkzugriff aus, sodass
  der 10-Sekunden-Refresh auch bei gestörter Namensauflösung nicht hängt.
- Für die Kommandozeile: `thmvpn-cleanup.sh --check` prüft nur, `thmvpn-cleanup.sh` räumt auf.

## Trennen

- Nach dem Trennen per Touch ID aktualisiert sich die Menüleiste **sofort** statt erst beim
  nächsten Refresh.

## Installation

- `install.sh` richtet den neuen **Aufräum-Helfer** `thmvpn-cleanup.sh` mit ein. Bestehende
  Installationen erhalten ihn durch erneutes Ausführen von `install.sh`.
- Die in SwiftBar angezeigte Plugin-Version entspricht jetzt der Release-Version (**v1.2.0**).

## Dokumentation

- Die README beschreibt im neuen Abschnitt **„Health-Check"**, welche Reste eine abgebrochene
  Sitzung hinterlässt, wie das Plugin sie erkennt und wie sie sich beseitigen lassen.
- Ein **Sicherheitshinweis** erläutert, welcher Code beim Verbinden und Aufräumen mit
  Administratorrechten läuft und wie sich eine gehärtete Einrichtung umsetzen ließe.
- Installation, Deinstallation und Dateiübersicht sind um den Aufräum-Helfer ergänzt.

---

*Getestet auf macOS (Apple Silicon) mit openconnect 9.21 und SwiftBar 2.1.*
