#!/usr/bin/env bash
set -euo pipefail

PLIST_ID="no.kopseng.minecraft-monitor"
COMPILED_NAME="minecraft-monitor.scpt"
SELECTED_USERS=()

main() {
    if [[ $# -gt 0 ]]; then
        SELECTED_USERS=($(echo "$1" | tr ',' '\n'))
    fi

    if [[ ${#SELECTED_USERS[@]} -eq 0 ]]; then
        list_mac_users
        prompt_for_users
    fi

    for user in "${SELECTED_USERS[@]}"; do
        user=$(echo "$user" | xargs)
        uninstall_for_user "$user"
    done

    echo "✅ Uninstall complete."
}

prompt_for_users(){
    echo
    read -rp "👤 Enter comma-separated list of usernames to uninstall for: " USER_INPUT
    IFS=',' read -ra SELECTED_USERS <<< "$USER_INPUT"
}

list_mac_users() {
    dscl . list /Users | while read -r user; do
        if [[ -d "/Users/$user" ]] && [[ "$user" != "_"* ]]; then
            echo "$user"
        fi
    done
}

uninstall_for_user() {
    local user=$1
    local home="/Users/$user"
    local app_support="$home/Library/Application Support/minecraft-monitor"
    local launch_agents="$home/Library/LaunchAgents"
    local agent_path="$launch_agents/$PLIST_ID.plist"

    if ! sudo -u "$user" test -e "$agent_path"; then
        echo "No existing agent found for user $user"
        return
    fi

    echo "🧹 Uninstalling for $user..."

    # From launchctl help text:
    #gui/<uid>/[service-name]
    #Targets the GUI domain or service within. Each GUI domain is associated with a
    #user domain, and a process running as the owner of that user domain may make
    #modifications. Root may modify any GUI domain. GUI domains do not exist on iOS.
    sudo launchctl bootout gui/"$(id -u "$user")" "$agent_path" 2>/dev/null || true


    # root-owned
    sudo rm -f "$agent_path"
    sudo rm -f "$app_support/$COMPILED_NAME"

    # set uninstall flag that the process checks for to exit!
    sudo touch "$app_support/.uninstall"

    # Leaving the log files, config and state, as we we might uninstall as part of upgrading to a newer version

    echo "✅ Cleaned up for $user (leaving log files, config and state file)"
}

main "$@"
