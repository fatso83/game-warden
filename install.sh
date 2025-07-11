#!/usr/bin/env bash
# Install the Minecraft monitor script as LaunchAgent for selected users
set -euo pipefail

PLIST_ID="no.kopseng.minecraft-monitor"
PLIST_FILENAME="$PLIST_ID.plist"
SCRIPT_NAME="minecraft-monitor.scpt"

APP_SUPPORT_SUBDIR="Library/Application Support/minecraft-monitor"
LAUNCH_AGENTS_SUBDIR="Library/LaunchAgents"

MONITOR_SCRIPT_SOURCE="minecraft-monitor.applescript"

main() {
    trap cleanup EXIT

    list_users
    prompt_for_users

    for username in "${selected_users[@]}"; do
        echo "📦 Installing for $username..."
        install_for_user "$username"
    done
}

cleanup() {
    rm -f "$PLIST_FILENAME"
}

list_users() {
    echo "📋 Available users:"
    dscl . list /Users | while read -r user; do
        if [[ -d "/Users/$user" ]] && [[ "$user" != "_"* ]]; then
            echo "$user"
         fi
     done
 }

prompt_for_users() {
    read -p "👤 Enter comma-separated list of usernames to install for: " user_input
    IFS=',' read -ra selected_users <<< "$user_input"
    for user in "${selected_users[@]}"; do
        homedir="/Users/$user"
        if [[ ! -d "$homedir" ]]; then
            echo "❌ Home directory for $user not found: $homedir"
            exit 1
        fi
    done
}

install_for_user() {
    local username="$1"
    local homedir="/Users/$username"
    local user_uid=$(id -u "$username")
    local user_gid=$(id -g "$username")

    local app_support="$homedir/$APP_SUPPORT_SUBDIR"
    local launch_agents="$homedir/$LAUNCH_AGENTS_SUBDIR"

    sudo -u "$username" mkdir -p "$app_support"
    sudo -u "$username" mkdir -p "$launch_agents"

    sudo cp config.plist "$app_support/config.plist"
    sudo osacompile -o "$app_support/$SCRIPT_NAME" "$MONITOR_SCRIPT_SOURCE"

    cat > "$PLIST_FILENAME" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/osascript</string>
        <string>$app_support/$SCRIPT_NAME</string>
        <string>$app_support/config.plist</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$app_support/error.log</string>
    <key>StandardOutPath</key>
    <string>$app_support/output.log</string>
</dict>
</plist>
EOF

    sudo cp "$PLIST_FILENAME" "$launch_agents/"
    sudo chown "$username:$user_gid" "$launch_agents/$PLIST_FILENAME"
    sudo chown "$username:$user_gid" "$app_support/$SCRIPT_NAME" "$app_support/config.plist"

    echo "ℹ️  To activate the LaunchAgent for $username, run the following command in their session:"
    echo "   launchctl bootstrap gui/$user_uid \"$launch_agents/$PLIST_FILENAME\""
    echo "✅ Installed for $username"
    echo
}

main
