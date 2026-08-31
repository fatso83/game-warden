#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

users_root="$temp_root/users"
stub_bin="$temp_root/bin"
sudo_log="$temp_root/sudo.log"
august_app_support="$users_root/august/Library/Application Support/game-warden"
oskar_app_support="$users_root/oskar/Library/Application Support/game-warden"
mkdir -p "$august_app_support/data" "$users_root/august/Library/LaunchAgents" \
    "$oskar_app_support/data" "$stub_bin"
touch "$users_root/august/Library/LaunchAgents/no.kopseng.game-warden.plist"
touch "$oskar_app_support/config.plist" "$oskar_app_support/data/usage-state.dat" \
    "$oskar_app_support/.uninstall"

cat > "$stub_bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SUDO_LOG"
EOF
chmod +x "$stub_bin/sudo"

output="$({ GW_USERS_ROOT="$users_root" SUDO_LOG="$sudo_log" PATH="$stub_bin:$PATH" \
    "$script_dir/reset-time.sh" august,oskar; })"

expected=$'📦 Resetting game time for august ...\nℹ️ oskar has no Game Warden installation.'
if [[ "$output" != "$expected" ]]; then
    printf 'unexpected output:\n%s\n' "$output" >&2
    exit 1
fi

if [[ ! -s "$sudo_log" ]]; then
    echo 'expected sudo to be invoked for august' >&2
    exit 1
fi
if ! grep -Fq "$users_root/august/Library/Application Support/game-warden/data/usage-state.dat" "$sudo_log" || \
   ! grep -Fq "$users_root/august/Library/Application Support/game-warden/data/.uninstall" "$sudo_log"; then
    echo 'sudo did not reference august paths' >&2
    exit 1
fi
if grep -Fqi oskar "$sudo_log"; then
    echo 'sudo must not be invoked for oskar' >&2
    exit 1
fi

echo 'reset-time test passed'
