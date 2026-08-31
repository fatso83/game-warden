# Reset reporting for missing installations

## Goal

When `reset-time.sh` is invoked with one or more usernames, report any requested
user who does not have Game Warden installed instead of attempting a reset for
that user.

## Design

The per-user loop will check for the installed LaunchAgent plist at
`/Users/<username>/Library/LaunchAgents/no.kopseng.game-warden.plist` before
emitting the existing reset progress line. This is the installation marker
because normal uninstalls intentionally retain the application-support
configuration and state.

- If it exists, print the existing reset progress message and reset usage state
  exactly as today.
- If it does not exist, do not invoke `sudo rm` or `sudo touch`; print
  `ℹ️ <username> has no Game Warden installation.` using the supplied username.
- Requests containing both installed and uninstalled users are handled in the
  supplied order, independently.

## Testing

Add a regression test that supplies a mixed user list and verifies the missing
user receives the information message and no reset actions are attempted for it.
