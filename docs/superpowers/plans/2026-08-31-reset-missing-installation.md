# Reset Missing Installation Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Report and skip each requested user who has no Game Warden installation when resetting usage time.

**Architecture:** Add a `GW_USERS_ROOT` test seam that defaults to `/Users`. The per-user loop will use the seam to check installation directories before progress output or privileged actions. A dependency-free Bash test will execute the real script as a child process against a temporary users root with an installed `august` fixture and uninstalled `oskar`, and place a stubbed `sudo` first on `PATH` to verify ordered output and actions.

**Tech Stack:** Bash, macOS filesystem conventions, temporary-directory test fixture.

---

### Task 1: Add a regression test for a missing installation

**Files:**

- Create: `tests/reset-time.sh`
- Test: `tests/reset-time.sh`

- [ ] **Step 1: Write the failing test**

Create a Bash test that creates a temporary users-root containing only `august/Library/Application Support/game-warden/data`, creates an executable `sudo` stub first on `PATH` that records its arguments, and runs `reset-time.sh august,oskar` as a child process with `GW_USERS_ROOT` set to the temporary root.

Assert output is in supplied order and consists of the existing reset-progress line for `august`, followed by `ℹ️ oskar has no Game Warden installation.`. Assert recorded privileged commands address August’s fixture paths and none contains `oskar`.

- [ ] **Step 2: Run the test to verify it fails**

Run `bash tests/reset-time.sh`. Expected: FAIL because the production script ignores the temporary users root, emits reset progress for Oskar, and invokes the sudo stub for Oskar rather than printing the missing-installation message.

### Task 2: Skip users without an installation

**Files:**

- Modify: `reset-time.sh:7-38`
- Test: `tests/reset-time.sh`

- [ ] **Step 1: Implement the minimal check**

Define `USERS_ROOT="${GW_USERS_ROOT:-/Users}"` and use it wherever `reset-time.sh` derives a user home, retaining `/Users` in normal operation. In the existing `for username` loop, check for `$USERS_ROOT/$username/$LAUNCH_AGENTS_SUBDIR/$PLIST_FILENAME` before the existing reset-progress line. This detects an active installation even when an earlier uninstall has retained configuration and state. When absent, print `ℹ️ $username has no Game Warden installation.` and continue to the next user. Do not otherwise change normal script execution or the reset commands for installed users.

- [ ] **Step 2: Run the regression test**

Run `bash tests/reset-time.sh`. Expected: PASS; it observes August’s existing reset progress, then Oskar’s exact information message, and no sudo calls for Oskar.

- [ ] **Step 3: Run static syntax validation**

Run `bash -n reset-time.sh tests/reset-time.sh`. Expected: exits 0 with no output.

- [ ] **Step 4: Commit**

Run `git add reset-time.sh tests/reset-time.sh` followed by `git commit -m "fix: report reset users without an installation"`.
