#!/usr/bin/env bash
# Install the game-warden script as LaunchAgent for selected users
set -euo pipefail

PLIST_ID="no.kopseng.game-warden"
PLIST_FILENAME="$PLIST_ID.plist"
SCRIPT_NAME="game-warden.scpt"

APP_SUPPORT_SUBDIR="Library/Application Support/game-warden"
LAUNCH_AGENTS_SUBDIR="Library/LaunchAgents"

MONITOR_SCRIPT_SOURCE="game-warden.applescript"

# global
SELECTED_USERS=()

main() {
    trap cleanup EXIT

    if [[ $# -gt 0 ]]; then
        SELECTED_USERS=($(echo "$1" | tr ',' '\n'))
    fi

    if [[ ${#SELECTED_USERS[@]} -eq 0 ]]; then
        list_users
        prompt_for_users
    fi

    for username in "${SELECTED_USERS[@]}"; do
        echo "📦 Installing for $username..."
        install_for_user "$username"
    done
}

cleanup() {
    rm -f "$PLIST_FILENAME"
}

list_users() {
    local user
    echo "📋 Available users:"
    dscl . list /Users | while read -r user; do
        if [[ -d "/Users/$user" ]] && [[ "$user" != "_"* ]]; then
            echo "$user"
         fi
     done
 }

prompt_for_users() {
    read -p "👤 Enter comma-separated list of usernames to install for: " user_input
    IFS=',' read -ra SELECTED_USERS <<< "$user_input"
    for user in "${SELECTED_USERS[@]}"; do
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

    local app_support="$homedir/$APP_SUPPORT_SUBDIR"
    local launch_agents="$homedir/$LAUNCH_AGENTS_SUBDIR"

    if sudo -u "$username" test -e "$app_support"; then
        sudo -u "$username" ./uninstall.sh "$username"

        # This should already have been removed by the application on detection
        (sleep 1.5; rm -f "$app_support/.uninstall" &)
    fi

    sudo -u "$username" mkdir -p "$app_support"
    sudo -u "$username" mkdir -p "$launch_agents"

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
    <key>KeepAlive</key>
    <true/>

    <!-- All log() statements in AppleScripts ends up on standard error -->
    <key>StandardErrorPath</key>
    <string>$app_support/error.log</string>

    <!-- We create an application.log to actually capture application output -->

    <!-- This is assumed to always be empty -->
    <key>StandardOutPath</key>
    <string>$app_support/output.log</string>
</dict>
</plist>
EOF

    sudo cp "$PLIST_FILENAME" "$launch_agents/"
    sudo osacompile -o "$app_support/$SCRIPT_NAME" "$MONITOR_SCRIPT_SOURCE"

    # do not overwrite configuration files the user has changed
    UNCHANGED_CONFIG_CHECKSUM=$(md5 --quiet config.plist)
    if ( [ -e "$app_support/config.plist" ] \
        &&  ! (md5 -c "$UNCHANGED_CONFIG_CHECKSUM" --quiet "$app_support/config.plist" > /dev/null)); then
        NEW_CONFIG="$app_support/config.plist.new"
        echo "Detected custom config: not overwriting."
        echo "Putting new reference config next to it as $NEW_CONFIG"
        sudo cp -f config.plist "$NEW_CONFIG"
    else
        sudo cp config.plist "$app_support/config.plist"
    fi

    # Ensure the agent files cannot just be removed by the user without having admin rights
    sudo chown "root:admin" "$launch_agents/$PLIST_FILENAME"
    sudo chown "root:admin" "$app_support/$SCRIPT_NAME" "$app_support/config.plist"


    sudo launchctl bootstrap "gui/$user_uid" "$launch_agents/$PLIST_FILENAME" || true
    echo "✅ Installed for $username"
    echo
}

main "$@"
