#!/usr/bin/env bash
set -euo pipefail

PLIST_ID="no.kopseng.minecraft-monitor"
COMPILED_NAME="minecraft-monitor.scpt"
CONFIG_NAME="config.plist"

main() {
    echo "📋 Available users:"
    list_mac_users

    echo
    read -rp "👤 Enter comma-separated list of usernames to uninstall for: " USER_INPUT
    IFS=',' read -ra USERS <<< "$USER_INPUT"

    for user in "${USERS[@]}"; do
        user=$(echo "$user" | xargs)
        uninstall_for_user "$user"
    done

    echo "✅ Uninstall complete."
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

    echo "🧹 Uninstalling for $user..."

    launchctl bootout gui/"$(id -u "$user")" "$agent_path" 2>/dev/null || true
    rm -f "$agent_path"

    rm -f "$app_support/$COMPILED_NAME" \
          "$app_support/$CONFIG_NAME" \
          "$app_support/minecraft-monitor.log" \
          "$app_support/minecraft-monitor.err" \
          "$app_support/mc-usage-state.txt"

    rmdir "$app_support" 2>/dev/null || true
    echo "✅ Cleaned up for $user"
}

main
