# vi: ft=bash
##################### DO NOT EDIT ####################
# Shared settings and functions for shell scripts
##################### DO NOT EDIT ####################

set -euo pipefail

PLIST_ID="no.kopseng.game-warden"
PLIST_FILENAME="$PLIST_ID.plist"
SCRIPT_NAME="game-warden.scpt"

APP_SUPPORT_SUBDIR="Library/Application Support/game-warden"
LAUNCH_AGENTS_SUBDIR="Library/LaunchAgents"

MONITOR_SCRIPT_SOURCE="game-warden.applescript"

# global
SELECTED_USERS=()

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
    PROMPT_TEXT="$1"
    read -p "$PROMPT_TEXT" user_input
    IFS=',' read -ra SELECTED_USERS <<< "$user_input"
    for user in "${SELECTED_USERS[@]}"; do
        homedir="/Users/$user"
        if [[ ! -d "$homedir" ]]; then
            echo "❌ Home directory for $user not found: $homedir"
            exit 1
        fi
    done
}

banner(){
cat << EOF

  ______   ______   ______   ______   ______   ______   ______   ______   ______   ______   ______
 /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/


 ._.    ________                         __      __                  .___                    ._.
 | |   /  _____/_____    _____   ____   /  \    /  \_____ _______  __| _/____   ____         | |
 |_|  /   \  ___\__  \  /     \_/ __ \  \   \/\/   /\__  \\_  __ \/ __ |/ __ \ /    \        |_|
 |-|  \    \_\  \/ __ \|  Y Y  \  ___/   \        /  / __ \|  | \/ /_/ \  ___/|   |  \       |-|
 | |   \______  (____  /__|_|  /\___  >   \__/\  /  (____  /__|  \____ |\___  >___|  /       | |
 |_|          \/     \/      \/     \/         \/        \/           \/    \/     \/        |_|


  ______   ______   ______   ______   ______   ______   ______   ______   ______   ______   ______
 /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/  /_____/

EOF
}
