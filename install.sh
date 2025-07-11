#!/usr/bin/env bash
set -euo pipefail

PLIST_TEMPLATE="./no.kopseng.minecraft-monitor.plist"
SCRIPT_SOURCE="./minecraft-monitor.applescript"
COMPILED_NAME="minecraft-monitor.scpt"
CONFIG_SOURCE="./config.plist"
PLIST_ID="no.kopseng.minecraft-monitor"

main() {
    echo "📋 Available users:"
    list_mac_users

    echo
    read -rp "👤 Enter comma-separated list of usernames to install for: " USER_INPUT
    IFS=',' read -ra USERS <<< "$USER_INPUT"

    for user in "${USERS[@]}"; do
        user=$(echo "$user" | xargs)
        install_for_user "$user"
    done

    echo "✅ Installation complete."
}

list_mac_users() {
    dscl . list /Users | while read -r user; do
        if [[ -d "/Users/$user" ]] && [[ "$user" != "_"* ]]; then
            echo "$user"
        fi
    done
}

install_for_user() {
    local user=$1
    local home="/Users/$user"
    local app_support="$home/Library/Application Support/minecraft-monitor"
    local launch_agents="$home/Library/LaunchAgents"
    local plist_dest="$launch_agents/$PLIST_ID.plist"

    if [[ ! -d "$home" ]]; then
        echo "⚠️  Home directory for $user not found: $home"
        return
    fi

    echo "📦 Installing for $user..."

    sudo -u "$user" mkdir -p "$app_support"
    sudo -u "$user" mkdir -p "$launch_agents"

    # Compile script
    osacompile -o "$app_support/$COMPILED_NAME" "$SCRIPT_SOURCE"
    cp -f "$CONFIG_SOURCE" "$app_support/"

    # Generate plist with correct paths
    cat > "$plist_dest" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/osascript</string>
        <string>$app_support/$COMPILED_NAME</string>
        <string>$app_support/$CONFIG_SOURCE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$app_support/minecraft-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>$app_support/minecraft-monitor.err</string>
</dict>
</plist>
EOF

    chown "$user" "$plist_dest"
    launchctl bootout gui/"$(id -u "$user")" "$plist_dest" 2>/dev/null || true
    launchctl bootstrap gui/"$(id -u "$user")" "$plist_dest"
    echo "✅ Installed and loaded agent for $user"
}

main
