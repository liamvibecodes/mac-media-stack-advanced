#!/usr/bin/env python3
"""Download Watchdog - detects stalled/slow torrents and auto-fixes or swaps them.

Runs every 15 minutes via launchd. Monitors Radarr/Sonarr queues and qBittorrent
for problematic downloads. Actions:
  1. First detection: reannounce + restart + top-priority
  2. Persistent stall (>30min): remove + blocklist to trigger auto-redownload
  3. Downloads past 25% progress are never auto-swapped (too much wasted bandwidth)
"""

import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
import http.cookiejar
from pathlib import Path

BASE_DIR = Path(os.path.expanduser("~/Media"))
STATE_FILE = BASE_DIR / "state" / "download-watchdog-state.json"
LOG_FILE = BASE_DIR / "logs" / "download-watchdog.log"
RADARR_CFG = BASE_DIR / "config" / "radarr" / "config.xml"
SONARR_CFG = BASE_DIR / "config" / "sonarr" / "config.xml"

RADARR_URL = os.getenv("RADARR_URL", "http://localhost:7878")
SONARR_URL = os.getenv("SONARR_URL", "http://localhost:8989")
QBIT_URL = os.getenv("QBIT_URL", "http://localhost:8080")

QBIT_USERNAME = os.getenv("QBIT_USERNAME", "admin")
QBIT_PASSWORD = os.getenv("QBIT_PASSWORD", "")

STALL_SECONDS = int(os.getenv("WATCHDOG_STALL_SECONDS", "1800"))
SLOW_SECONDS = int(os.getenv("WATCHDOG_SLOW_SECONDS", "1200"))
MIN_SPEED_BPS = int(os.getenv("WATCHDOG_MIN_SPEED_BPS", str(300 * 1024)))
MAX_SWAP_PROGRESS = float(os.getenv("WATCHDOG_MAX_SWAP_PROGRESS", "0.25"))

STALL_STATES = {"stalledDL", "metaDL"}
SLOW_STATES = {"downloading", "stalledDL", "metaDL", "queuedDL", "forcedDL"}


def ts():
    return time.strftime("%Y-%m-%d %H:%M:%S")


def log(msg):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a") as f:
        f.write(f"{ts()} {msg}\n")


def parse_api_key_xml(path):
    if not path.exists():
        return ""
    text = path.read_text(errors="ignore")
    start = text.find("<ApiKey>")
    end = text.find("</ApiKey>")
    if start == -1 or end == -1:
        return ""
    return text[start + 8 : end].strip()


def http_json(url, headers=None, timeout=30):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def make_qbit_opener():
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    payload = urllib.parse.urlencode(
        {"username": QBIT_USERNAME, "password": QBIT_PASSWORD}
    ).encode()
    req = urllib.request.Request(
        f"{QBIT_URL.rstrip('/')}/api/v2/auth/login", data=payload, method="POST"
    )
    with opener.open(req, timeout=15) as resp:
        body = resp.read().decode(errors="ignore").strip()
    if body != "Ok.":
        raise RuntimeError("qBittorrent auth failed")
    return opener


def qbit_get_torrent(opener, h):
    url = f"{QBIT_URL.rstrip('/')}/api/v2/torrents/info?hashes={urllib.parse.quote(h)}"
    with opener.open(urllib.request.Request(url), timeout=20) as resp:
        items = json.loads(resp.read())
    return items[0] if items else None


def qbit_action(opener, endpoint, h):
    url = f"{QBIT_URL.rstrip('/')}{endpoint}"
    payload = urllib.parse.urlencode({"hashes": h}).encode()
    with opener.open(
        urllib.request.Request(url, data=payload, method="POST"), timeout=20
    ):
        pass


def arr_queue(base_url, api_key):
    url = f"{base_url.rstrip('/')}/api/v3/queue?page=1&pageSize=200&sortKey=added&sortDirection=descending"
    return http_json(url, headers={"X-Api-Key": api_key}).get("records", [])


def arr_remove_queue(base_url, api_key, queue_id):
    query = urllib.parse.urlencode(
        {"removeFromClient": "true", "blocklist": "true", "skipRedownload": "false"}
    )
    url = f"{base_url.rstrip('/')}/api/v3/queue/{queue_id}?{query}"
    req = urllib.request.Request(url, method="DELETE", headers={"X-Api-Key": api_key})
    with urllib.request.urlopen(req, timeout=30):
        pass


def classify_problem(item, arr_error):
    state = item.get("state", "")
    speed = int(item.get("dlspeed", 0) or 0)
    progress = float(item.get("progress", 0.0) or 0.0)
    if "stalled" in (arr_error or "").lower() or state in STALL_STATES:
        return "stalled"
    if progress < 0.995 and state in SLOW_STATES and speed < MIN_SPEED_BPS:
        return "slow"
    return None


def load_state():
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not STATE_FILE.exists():
        return {"items": {}}
    try:
        data = json.loads(STATE_FILE.read_text())
        if not isinstance(data, dict) or "items" not in data:
            return {"items": {}}
        return data
    except Exception:
        return {"items": {}}


def save_state(state):
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(STATE_FILE)


def main():
    radarr_key = os.getenv("RADARR_API_KEY") or parse_api_key_xml(RADARR_CFG)
    sonarr_key = os.getenv("SONARR_API_KEY") or parse_api_key_xml(SONARR_CFG)

    if not radarr_key and not sonarr_key:
        log("[ERROR] No API keys found")
        return 1

    try:
        qbit = make_qbit_opener()
    except Exception as exc:
        log(f"[ERROR] qBittorrent login failed: {exc}")
        return 1

    state = load_state()
    now = int(time.time())
    seen = set()

    apps = []
    if radarr_key:
        apps.append(("radarr", RADARR_URL, radarr_key))
    if sonarr_key:
        apps.append(("sonarr", SONARR_URL, sonarr_key))

    for app_name, app_url, app_key in apps:
        try:
            queue = arr_queue(app_url, app_key)
        except Exception as exc:
            log(f"[ERROR] {app_name} queue fetch failed: {exc}")
            continue

        for rec in queue:
            torrent_hash = (rec.get("downloadId") or "").strip()
            if not torrent_hash:
                continue

            seen.add(torrent_hash)
            title = rec.get("title", "unknown")
            queue_id = int(rec.get("id", 0))
            arr_error = rec.get("errorMessage", "")

            try:
                t = qbit_get_torrent(qbit, torrent_hash)
            except Exception:
                continue

            if not t:
                state["items"].pop(torrent_hash, None)
                continue

            problem = classify_problem(t, arr_error)
            speed = int(t.get("dlspeed", 0) or 0)
            qstate = t.get("state", "")
            progress = float(t.get("progress", 0.0) or 0.0)

            if problem is None:
                if torrent_hash in state["items"]:
                    log(f"[RECOVERED] {app_name} {title}")
                    del state["items"][torrent_hash]
                continue

            entry = state["items"].get(torrent_hash)
            if not entry:
                entry = {
                    "app": app_name,
                    "queue_id": queue_id,
                    "title": title,
                    "problem_type": problem,
                    "first_problem_ts": now,
                    "retry_done": False,
                    "hold_logged": False,
                }
                state["items"][torrent_hash] = entry
                log(
                    f"[DETECTED] {app_name} {title} issue={problem} state={qstate} speed={speed}B/s"
                )
            else:
                entry.update(
                    app=app_name, queue_id=queue_id, title=title, problem_type=problem
                )

            if not entry.get("retry_done"):
                try:
                    qbit_action(qbit, "/api/v2/torrents/reannounce", torrent_hash)
                    qbit_action(qbit, "/api/v2/torrents/start", torrent_hash)
                    qbit_action(qbit, "/api/v2/torrents/topPrio", torrent_hash)
                    entry["retry_done"] = True
                    log(f"[RETRY] {app_name} {title} action=reannounce,start,topPrio")
                except Exception as exc:
                    log(f"[WARN] retry failed for {title}: {exc}")
                continue

            age = now - int(entry.get("first_problem_ts", now))
            threshold = STALL_SECONDS if problem == "stalled" else SLOW_SECONDS
            if age < threshold:
                continue

            if progress >= MAX_SWAP_PROGRESS:
                if not entry.get("hold_logged"):
                    pct = round(progress * 100, 1)
                    log(
                        f"[HOLD] {app_name} keeping {title} progress={pct}% (auto-swap disabled)"
                    )
                    entry["hold_logged"] = True
                continue

            try:
                arr_remove_queue(app_url, app_key, queue_id)
                log(
                    f"[SWAP] {app_name} removed+blocklisted: {title} age={age}s issue={problem}"
                )
                del state["items"][torrent_hash]
            except Exception as exc:
                log(f"[ERROR] queue delete failed: {exc}")

    # Prune stale
    for h in [h for h in state["items"] if h not in seen]:
        del state["items"][h]

    save_state(state)
    log("[INFO] watchdog run complete")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        log(f"[ERROR] unhandled: {exc}")
        raise
