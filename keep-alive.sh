#!/usr/bin/env bash
# USAGE: this script is supposed to be put in your crontab. 
NAME=minecraft-monitor.scpt
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

main(){
    start_if_not_running

    handle_user_change
}

start_if_not_running(){
    if ! pgrep -f "osascript.*$NAME" >/dev/null; then
        osascript "$SCRIPT_DIR/$NAME" "$SCRIPT_DIR/config.plist" &
    fi
}

handle_user_change(){
    local current_user;
    local previous_user;
    # File to keep track of last seen user
    local STATE_FILE
    STATE_FILE="/tmp/minecraft-last-user"

    # Get current GUI user
    current_user=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

    # Get previous user
    if [[ -f "$STATE_FILE" ]]; then
        previous_user=$(cat "$STATE_FILE")
    else
        previous_user=""
    fi

    # Compare
    if [[ "$current_user" != "$previous_user" && -n "$current_user" ]]; then
        log "User changed from $previous_user to $current_user"

        # Kill any running instance of the monitor
        pkill -f "osascript.*minecraft-monitor"

        # Restart script as new user
        #launchctl asuser $(id -u "$current_user") sudo -u "$current_user" \
        #osascript /Users/Shared/minecraft-monitor/minecraft-monitor.scpt &
        start_if_not_running
    fi

    # Save state
    echo "$current_user" > "$STATE_FILE"
}

log(){
    echo "$*" | tee -a "$SCRIPT_DIR/data/keep-alive.log"
}

main
