"""Read-only campaign inventory and point-in-time public game counters."""

import re
import time
from urllib.parse import urlencode
from urllib.request import Request

from roblox_ads_api import MetricError, request_json


def _validate_universe(universe):
    if not isinstance(universe, str) or not re.fullmatch(r"[1-9][0-9]*", universe):
        raise ValueError("Invalid universe ID")


def fetch_campaigns(key: str, universe: str) -> list[dict]:
    """Read every campaign for one universe, keeping only its identity and delivery state."""
    _validate_universe(universe)
    if not key or not all(33 <= ord(char) <= 126 for char in key):
        raise ValueError("Invalid API key format")

    url = "https://apis.roblox.com/ads-management/v1/campaigns"
    params = {"targetUniverseIds": universe, "maxPageSize": "100"}
    headers = {"x-api-key": key, "Accept": "application/json"}
    deadline = time.monotonic() + 90
    campaigns = {}
    seen_tokens = set()
    while True:
        request = Request(url + "?" + urlencode(params), headers=headers)
        page = request_json(request, deadline)
        rows = page.get("campaigns", [])
        if not isinstance(rows, list) or "errors" in page or "error" in page:
            raise MetricError("Invalid Roblox campaigns response")
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"]:
                raise MetricError("Campaign has no valid ID")
            if "targetUniverseId" in row and str(row["targetUniverseId"]) != universe:
                raise MetricError("Roblox returned a campaign for a different universe")
            name = row.get("name", row["id"])
            status = row.get("deliveryStatus", "UNKNOWN")
            if not isinstance(name, str) or not isinstance(status, str):
                raise MetricError("Invalid Roblox campaign details")
            campaigns[row["id"]] = {"id": row["id"], "name": name, "deliveryStatus": status}
        token = page.get("nextPageToken")
        if token is None or token == "":
            return list(campaigns.values())
        if not isinstance(token, str) or token in seen_tokens:
            raise MetricError("Invalid Roblox campaign page token")
        params["pageToken"] = token
        seen_tokens.add(token)


def fetch_public(universe: str) -> dict:
    """Return the public counters observed at request time, without sending credentials."""
    _validate_universe(universe)
    url = "https://games.roblox.com/v1/games?" + urlencode({"universeIds": universe})
    result = request_json(Request(url, headers={"Accept": "application/json"}), time.monotonic() + 60)
    rows = result.get("data")
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        raise MetricError("Roblox did not return the requested game")
    game = rows[0]
    if str(game.get("id")) != universe:
        raise MetricError("Roblox returned a different game")
    counts = {field: game.get(field) for field in ("playing", "visits")}
    if any(type(count) is not int or count < 0 for count in counts.values()):
        raise MetricError("Invalid public game counters")
    return counts
