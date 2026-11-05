#!/bin/bash
# Gemeinsamer Helfer fuer Terminal-Fenster, die die THM-VPN-Skripte selbst
# oeffnen. Wird von thmvpn-connect.sh, thmvpn-disconnect.sh und
# thmvpn-cleanup.sh per "." eingebunden:
#
#   relaunch_in_terminal             ohne Terminal: Skript in einem Fenster neu
#                                    starten; im Fenster: OWN_WINDOW setzen
#   close_own_window_if <status> [verzoegerung]
#                                    eigenes Fenster schliessen, wenn <status>
#                                    0 ist; Rueckgabe 0 = Fenster schliesst sich
#
# Direkt aufgerufen (thmvpn-closewindow.sh <tty> [verzoegerung]) wartet das
# Skript im Hintergrund, bis im Fenster nichts mehr laeuft, und schliesst es.
#
# Das osascript laeuft als Kindprozess von Terminal.app, steuert also Terminal
# selbst - dafuer ist keine Automations-Freigabe noetig.
#
# Nicht als root einbinden: Die Datei gehoert dem Benutzer.
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-closewindow.sh

THMVPN_WINDOW_HELPER="${BASH_SOURCE[0]}"

# Ohne Terminal gestartet (z.B. von SwiftBar)? -> in einem Terminal neu starten.
# Die Markerdatei merkt sich, dass das Fenster nur fuer dieses Skript geoeffnet
# wurde. Sie gilt je Skript und nur kurz: Ein Rest eines gescheiterten Starts
# darf spaeter nicht als eigenes Fenster durchgehen.
relaunch_in_terminal() {
  local marker
  marker="${TMPDIR:-/tmp}/thmvpn-own-window.$(/usr/bin/basename "$0")"
  if [ ! -t 0 ]; then
    /usr/bin/touch "$marker"
    /usr/bin/open -a Terminal "$0" || /bin/rm -f "$marker"
    exit
  fi
  OWN_WINDOW=0
  [ -n "$(/usr/bin/find "$marker" -mtime -60s 2>/dev/null)" ] && OWN_WINDOW=1
  /bin/rm -f "$marker"
}

# Startet das Schliessen im Hintergrund. setsid loest den Prozess vom TTY des
# Fensters, damit er dort nicht selbst als laufender Prozess zaehlt.
close_own_window_if() {
  local status="$1" delay="${2:-0}" tty
  [ "$status" -eq 0 ] && [ "${OWN_WINDOW:-0}" -eq 1 ] && [ -x /usr/bin/perl ] || return 1
  tty=$(/usr/bin/tty) || return 1
  /usr/bin/perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' \
    /bin/bash "$THMVPN_WINDOW_HELPER" "$tty" "$delay" </dev/null >/dev/null 2>&1 &
  disown
}

# Schliesst das Fenster erst, wenn auf seinem TTY kein Prozess mehr laeuft.
# Lebt dort nach 30 s noch etwas (z.B. eine interaktive Shell), bleibt es offen.
# Fenster mit mehreren Tabs bleiben ebenfalls offen, damit keine fremden Tabs
# mitgeschlossen werden.
close_window_when_idle() {
  local tty="$1" delay="${2:-0}" tries=0
  sleep "$delay"
  while [ -n "$(/bin/ps -t "${tty#/dev/}" -o pid= 2>/dev/null)" ]; do
    tries=$((tries + 1))
    [ "$tries" -ge 150 ] && return 1
    sleep 0.2
  done
  sleep 0.2
  /usr/bin/osascript \
    -e 'on run argv' \
    -e 'tell application "Terminal"' \
    -e 'repeat with w in windows' \
    -e 'if (count of tabs of w) is 1 and tty of tab 1 of w is (item 1 of argv) then' \
    -e 'close w' \
    -e 'return' \
    -e 'end if' \
    -e 'end repeat' \
    -e 'end tell' \
    -e 'end run' "$tty"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  close_window_when_idle "$@"
fi
