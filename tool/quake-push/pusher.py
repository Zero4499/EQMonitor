#!/usr/bin/env python3
"""QuakePush reference poller.

Polls the USGS earthquake summary feed and the NOAA/tsunami.gov Atom feeds and
publishes new events to an ntfy topic, which the Android app subscribes to.
Standard library only; no third-party dependencies.

Configure by environment variables (all optional):

    NTFY_SERVER      default https://ntfy.sh
    NTFY_TOPIC       required, e.g. quake-52e3e857741b43fb
    USGS_FEED        default .../summary/all_hour.geojson
    MIN_MAG          minimum magnitude to publish (default 4.5)
    QUAKE_INTERVAL   seconds between USGS polls (default 30)
    TSUNAMI_INTERVAL seconds between tsunami.gov polls (default 60)
    STATE_FILE       default ./state.json

The state file keeps the ids already published so a restart does not re-alert.
"""

from __future__ import annotations

import json
import os
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

NTFY_SERVER = os.environ.get("NTFY_SERVER", "https://ntfy.sh").rstrip("/")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "quake-52e3e857741b43fb")
USGS_FEED = os.environ.get(
    "USGS_FEED",
    "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson",
)
TSUNAMI_FEEDS = (
    "https://www.tsunami.gov/events/xml/PHEBAtom.xml",
    "https://www.tsunami.gov/events/xml/PAAQAtom.xml",
)
MIN_MAG = float(os.environ.get("MIN_MAG", "4.5"))
QUAKE_INTERVAL = int(os.environ.get("QUAKE_INTERVAL", "30"))
TSUNAMI_INTERVAL = int(os.environ.get("TSUNAMI_INTERVAL", "60"))
STATE_FILE = Path(os.environ.get("STATE_FILE", "state.json"))


def http_get(url: str, timeout: int = 20) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "QuakePush/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


def load_state() -> dict[str, list[str]]:
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text("utf-8"))
            return {
                "quakes": list(data.get("quakes", [])),
                "tsunami": list(data.get("tsunami", [])),
            }
        except (json.JSONDecodeError, OSError):
            pass
    return {"quakes": [], "tsunami": []}


def save_state(state: dict[str, list[str]]) -> None:
    # keep the state bounded so it never grows without limit
    state["quakes"] = state["quakes"][-500:]
    state["tsunami"] = state["tsunami"][-200:]
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), "utf-8")


def publish(title: str, message: str, priority: int, tags: list[str], click: str) -> None:
    payload: dict[str, Any] = {
        "topic": NTFY_TOPIC,
        "title": title,
        "message": message,
        "priority": priority,
        "tags": tags,
    }
    if click:
        payload["click"] = click
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        NTFY_SERVER,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        response.read()


def quake_priority(mag: float, pager: str | None) -> int:
    if mag >= 7 or pager == "red":
        return 5
    if mag >= 6 or pager == "orange":
        return 4
    return 3


def poll_quakes(state: dict[str, list[str]]) -> None:
    body = http_get(USGS_FEED)
    features = json.loads(body).get("features", [])
    seen = set(state["quakes"])
    first_run = not seen
    new_ids: list[str] = []
    for feature in features:
        props = feature.get("properties") or {}
        event_id = feature.get("id")
        if not event_id or event_id in seen:
            continue
        new_ids.append(event_id)
        mag = props.get("mag")
        if mag is None or float(mag) < MIN_MAG:
            continue
        if first_run:
            # do not blast a burst of notifications when the service first starts
            continue
        place = (props.get("place") or "unknown location").strip()
        ts = props.get("time")
        when = (
            datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
            .astimezone()
            .strftime("%Y-%m-%d %H:%M")
            if isinstance(ts, (int, float))
            else "unknown"
        )
        mag_text = f"M{float(mag):.1f}"
        pager = props.get("alert")
        alert = quake_priority(float(mag), pager) >= 5
        title = f"{'🚨' if alert else '🌍'} {mag_text} quake: {place}"
        message = (
            f"**{mag_text}** {place}\n\n"
            f"Time: {when}\n"
            f"PAGER: {pager or 'none'}"
            f"{f' · Tsunami flag' if props.get('tsunami') else ''}\n"
            f"{props.get('url') or ''}"
        )
        publish(
            title=title,
            message=message,
            priority=quake_priority(float(mag), pager),
            tags=["🚨" if alert else "earthquake"],
            click=props.get("url") or "",
        )
        print(f"[quake] {mag_text} {place}", flush=True)
    state["quakes"].extend(new_ids)


def tsunami_priority(title: str) -> int:
    lowered = title.lower()
    if "warning" in lowered or "threat" in lowered:
        return 5
    if "watch" in lowered or "advisory" in lowered:
        return 4
    return 3


def poll_tsunami(state: dict[str, list[str]]) -> None:
    seen = set(state["tsunami"])
    first_run = not seen
    new_ids: list[str] = []
    for feed in TSUNAMI_FEEDS:
        try:
            root = ET.fromstring(http_get(feed))
        except (OSError, ET.ParseError) as error:
            print(f"[tsunami] feed error {feed}: {error}", flush=True)
            continue
        for entry in root.iter():
            if not entry.tag.endswith("entry"):
                continue
            fields = {
                child.tag.split("}")[-1]: (child.text or "").strip()
                for child in entry
            }
            entry_id = fields.get("id")
            title = fields.get("title") or "Tsunami bulletin"
            if not entry_id or entry_id in seen:
                continue
            new_ids.append(entry_id)
            if first_run:
                continue
            link = next(
                (
                    child.attrib.get("href", "")
                    for child in entry
                    if child.tag.endswith("link")
                ),
                "",
            )
            priority = tsunami_priority(title)
            publish(
                title=f"{'🚨' if priority >= 5 else '🌊'} {title}",
                message=f"**{title}**\n\n{fields.get('updated', '')}\n{link}",
                priority=priority,
                tags=["🌊"],
                click=link,
            )
            print(f"[tsunami] {title}", flush=True)
    state["tsunami"].extend(new_ids)


def main() -> None:
    state = load_state()
    next_quake = 0.0
    next_tsunami = 0.0
    while True:
        now = time.monotonic()
        try:
            if now >= next_quake:
                next_quake = now + QUAKE_INTERVAL
                poll_quakes(state)
            if now >= next_tsunami:
                next_tsunami = now + TSUNAMI_INTERVAL
                poll_tsunami(state)
            save_state(state)
        except Exception as error:  # keep the loop alive on any network hiccup
            print(f"[loop] {type(error).__name__}: {error}", flush=True)
        time.sleep(5)


if __name__ == "__main__":
    main()
