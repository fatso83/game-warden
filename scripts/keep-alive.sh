#!/usr/bin/env bash
# USAGE: this script is supposed to be put in your crontab. 
NAME=minecraft-monitor.scpt
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if ! pgrep -f "osascript.*$NAME" >/dev/null; then
    osascript "$SCRIPT_DIR/$NAME" "$SCRIPT_DIR/config.plist" &
fi
