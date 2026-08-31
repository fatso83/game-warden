# Reset reporting for missing installations

## Goal

When `reset-time.sh` is invoked with one or more usernames, report any requested
user who does not have Game Warden installed instead of attempting a reset for
that user.

## Design

`reset_time` will first check for the user’s Game Warden application-support
directory at `/Users/<username>/Library/Application Support/game-warden`.

- If it exists, reset usage state exactly as today and retain the existing reset
  progress message.
- If it does not exist, do not invoke `sudo rm` or `sudo touch`; print
  `ℹ️ <username> has no Game Warden installation.` using the supplied username.
- Requests containing both installed and uninstalled users are handled in the
  supplied order, independently.

## Testing

Add a regression test that supplies a mixed user list and verifies the missing
user receives the information message and no reset actions are attempted for it.
