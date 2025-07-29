#!/usr/bin/env python3
import os, selectors, plistlib, time, json, re, signal

FIFO_PATH     = "/tmp/game-warden.fifo"
CONFIG_ROOT   = "/opt/game-warden/config"
SEL_TIMEOUT   = 1.0        # seconds
DATEFMT       = "%Y-%m-%dT%H:%M:%SZ"

sel = selectors.DefaultSelector()
users = {}   # username → user_record

# ─── Utilities ────────────────────────────────────────────────────────────────

def load_config(username):
    """Load per-user config.plist into a dict, caching it."""
    d = users.setdefault(username, {})
    if "config" not in d:
        p = os.path.join(CONFIG_ROOT, username, "config.plist")
        with open(p, "rb") as f:
            cfg = plistlib.load(f)
        # normalize
        cfg["dailyMaxSec"]   = parse_hhmm(cfg.get("dailyMax","01:00"))
        cfg["weeklyMaxSec"]  = parse_hhmm(cfg.get("weeklyMax","05:00"))
        cfg["patterns"]      = [re.compile(rx) for rx in cfg.get("processPatterns", [])]
        d["config"] = cfg
    return d["config"]

def load_state(username):
    """Load (or initialize) per-user state from JSON file."""
    d = users.setdefault(username, {})
    if "state" not in d:
        path = os.path.join(CONFIG_ROOT, username, "user-state.dat")
        try:
            with open(path) as f:
                state = json.load(f)
        except FileNotFoundError:
            # new state
            state = {
                "initialDaily":  0,
                "initialWeekly": 0,
                "last_ts":       None,
                "warned":        False
            }
        state["_path"] = path
        d["state"] = state
    return d["state"]

def save_state(username):
    state = users[username]["state"]
    with open(state["_path"], "w") as f:
        json.dump({k:v for k,v in state.items() if not k.startswith("_")}, f)

def parse_hhmm(s):
    h,m = s.split(":")
    return int(h)*3600 + int(m)*60

# ─── Core logic ───────────────────────────────────────────────────────────────

def handle_event(line):
    """
    Expect lines in the FIFO like:
      <username> <pid> <processName>
    """
    parts = line.split(None, 2)
    if len(parts) != 3:
        # TODO: log error
        return
    user, pid_s, pname = parts
    pid = int(pid_s)

    try:
        cfg = load_config(user)
    except FileNotFoundError:
        # TODO: log error / inform not recording event without a user config present
        return

    state = load_state(user)
    now = time.time()

    # Compute delta since last report
    last = state["last_ts"] or now
    delta = now - last
    state["last_ts"] = now

    # Check whether this pid's command line matches any pattern
    cmd = os.popen(f"ps -p {pid} -o command=").read().strip()
    if any(rx.search(cmd) for rx in cfg["patterns"]):
        # accumulate usage
        state["initialDaily"]  += delta
        state["initialWeekly"] += delta

        # warnings?
        if (not state["warned"] and
            (state["initialDaily"]  > cfg["dailyMaxSec"]-60 or
             state["initialWeekly"] > cfg["weeklyMaxSec"]-60)):
            os.system(f'''osascript -e 'display notification "5 minutes left" with title "Game Warden for {user}"' ''')
            state["warned"] = True

        # hard exit?
        if (state["initialDaily"]  > cfg["dailyMaxSec"]+5 or
            state["initialWeekly"] > cfg["weeklyMaxSec"]+5):
            os.kill(pid, signal.SIGKILL)

    else:
        # no match: reset session warning flag
        state["warned"] = False

    save_state(user)


def do_periodic_tasks():
    """
    Called every SEL_TIMEOUT when no FIFO data arrives.
    Could be used to flush state, roll over daily/weekly counters, etc.
    """
    now = time.localtime()
    for user,d in users.items():
        state = d["state"]
        cfg   = d["config"]
        # daily rollover?
        last_ts = state["last_ts"] or time.time()
        if time.strftime("%Y-%m-%d", time.localtime(last_ts)) != time.strftime("%Y-%m-%d", now):
            state["initialDaily"] = 0
            state["warned"] = False
            save_state(user)
        # weekly rollover?
        # (similar logic using isocalendar()[1])

# ─── Setup FIFO & Selector ────────────────────────────────────────────────────

if not os.path.exists(FIFO_PATH):
    os.mkfifo(FIFO_PATH, 0o600)

fd = os.open(FIFO_PATH, os.O_RDONLY | os.O_NONBLOCK)
sel.register(fd, selectors.EVENT_READ)

print("Game‑warden daemon started, waiting for client events…")

# ─── Event Loop ───────────────────────────────────────────────────────────────

try:
    while True:
        events = sel.select(timeout=SEL_TIMEOUT)
        if events:
            data = os.read(fd, 4096).decode(errors="ignore")
            for line in data.splitlines():
                handle_event(line)
        else:
            do_periodic_tasks()
finally:
    sel.unregister(fd)
    os.close(fd)
