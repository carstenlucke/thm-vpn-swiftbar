#!/bin/bash
# Schliesst das Terminal-Fenster zum uebergebenen TTY, nachdem das aufrufende
# Skript beendet ist (solange dort noch ein Prozess laeuft, wuerde Terminal
# beim Schliessen nachfragen). Aufruf im Hintergrund aus dem Fenster heraus:
#
#   nohup thmvpn-closewindow.sh "$(tty)" "$$" </dev/null >/dev/null 2>&1 &
#
# Das zweite Argument ist die PID des aufrufenden Skripts; auf deren Ende wird
# gewartet, danach noch kurz auf das Ende der Shell im Fenster.
#
# Das osascript laeuft als Kindprozess von Terminal.app, steuert also Terminal
# selbst - dafuer ist keine Automations-Freigabe noetig. Fenster mit mehreren
# Tabs bleiben offen, damit keine fremden Tabs mitgeschlossen werden.
#
# Liegt nach der Installation in ~/.config/swiftbar/thmvpn-closewindow.sh

if [ -n "$2" ]; then
  while kill -0 "$2" 2>/dev/null; do sleep 0.2; done
fi
sleep 1
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
  -e 'end run' "$1"
