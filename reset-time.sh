#!/usr/bin/env bash
# To execute this script without password, do this:
# echo '%admin ALL = (ALL) NOPASSWD: /usr/local/bin/game-warden-reset-time' | sudo tee /etc/sudoers.d/game-warden'
# You can now do `sudo game-warden-reset-time`

set -euo pipefail

SOURCE="$0"

main(){
    # globals SELECTED_USERS
    move_to_original_source_directory
    source shared.inc

    if [[ $# -gt 0 ]]; then
        IFS=, read -a SELECTED_USERS <<< "$1"
    fi

    if [[ ${#SELECTED_USERS[@]} -eq 0 ]]; then
        echo
        echo
        list_users
        prompt_for_users "👤 Enter name of username to reset game time for: "
    fi

    for username in "${SELECTED_USERS[@]}"; do
        echo "📦 Resetting game time for $username ..."
        reset_time "$username"
    done
}

reset_time(){
    local username="$1"
    local homedir="/Users/$username"

    local user_data="$homedir/$APP_SUPPORT_SUBDIR/data"

    sudo rm -f "$user_data/usage-state.dat"
    sudo touch "$user_data/.uninstall" #triggers re-reading
}

move_to_original_source_directory(){
    while [ -L "$SOURCE" ]; do
        ORIGINAL_SCRIPT_LOCATION="$(cd -P "$(dirname "$SOURCE")" && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$ORIGINAL_SCRIPT_LOCATION/$SOURCE"
    done
    ORIGINAL_SCRIPT_LOCATION="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    #echo "Real script path: $ORIGINAL_SCRIPT_LOCATION/$(basename "$SOURCE")"

    # ensure all references are relative to the original script location
    pushd "$ORIGINAL_SCRIPT_LOCATION" > /dev/null
}

main $@
