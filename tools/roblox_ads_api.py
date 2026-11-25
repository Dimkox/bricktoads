"""Read numeric universe-wide time series from the Roblox Analytics Query API."""

import json
import math
import re
import time
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener


BASE = "https://apis.roblox.com/analytics-query-api/"
MAX_BYTES = 4 * 1024 * 1024


class MetricError(RuntimeError):
    """The query failed or its response could not be interpreted safely."""


class MetricUnavailable(MetricError):
    """Roblox explicitly reported that this universe cannot query this metric."""


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _utc_bucket(dt, granularity):
    if dt.utcoffset() is None:
        raise ValueError("Expected a timezone-aware timestamp")
    dt = dt.astimezone(timezone.utc)
    if dt.microsecond or dt.second or dt.minute or (granularity == "OneDay" and dt.hour):
        raise ValueError("Timestamp is not aligned to a UTC bucket")
    return dt


def _iso(dt):
    return dt.isoformat(timespec="seconds").replace("+00:00", "Z")


def _pause(seconds, deadline):
    if time.monotonic() + seconds >= deadline:
        raise MetricError("Roblox query timed out")
    time.sleep(seconds)


def _retry_delay(header, fallback):
    if header:
        try:
            if header.isdigit():
                return max(fallback, int(header))
            retry_at = parsedate_to_datetime(header)
            return max(fallback, retry_at.timestamp() - time.time())
        except (ValueError, TypeError, OverflowError):
            pass
    return fallback


def request_json(request, deadline, *, metric_universe=None):
    """Fetch a Roblox JSON object within a monotonic deadline, without redirects."""
    opener = build_opener(_NoRedirect())
    for attempt in range(3):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise MetricError("Roblox query timed out")
        delay = 2 ** attempt
        try:
            with opener.open(request, timeout=min(20, remaining)) as response:
                if response.status != 200 and not (response.status == 202 and metric_universe is not None):
                    raise MetricError(f"Unexpected Roblox HTTP {response.status}")
                body = response.read(MAX_BYTES + 1)
                if len(body) > MAX_BYTES:
                    raise MetricError("Roblox query response exceeds size limit")
                try:
                    data = json.loads(body)
                except (ValueError, UnicodeError, RecursionError):
                    raise MetricError("Invalid Roblox JSON response") from None
                if not isinstance(data, dict):
                    raise MetricError("Invalid Roblox response object")
                return data
        except HTTPError as exc:
            with exc:
                if exc.code == 400 and metric_universe is not None:
                    try:
                        body = json.loads(exc.read(8192))
                    except (ValueError, UnicodeError, RecursionError):
                        body = None
                    error = body.get("error") if isinstance(body, dict) else None
                    if (isinstance(error, dict) and body.get("done") is True and error.get("code") == 2001 and
                            error.get("message") == f"Query is not available for Universe with id {metric_universe}"):
                        raise MetricUnavailable("Metric unavailable for this universe") from None
                if exc.code not in (408, 429, 500, 502, 503, 504) or attempt == 2:
                    raise MetricError(f"Roblox HTTP {exc.code}") from None
                delay = _retry_delay(exc.headers.get("Retry-After"), delay)
        except (URLError, OSError, HTTPException):
            if attempt == 2:
                raise MetricError("Network error contacting Roblox") from None
        _pause(delay, deadline)


def _points(response, granularity, start, end):
    values = response.get("values") if isinstance(response, dict) else None
    if not isinstance(values, list) or len(values) > 1:
        raise MetricError("Expected at most one universe-wide metric series")
    if not values:
        return {}
    series = values[0]
    if (not isinstance(series, dict) or series.get("breakdowns", []) != [] or
            not isinstance(series.get("dataPoints"), list)):
        raise MetricError("Invalid universe-wide metric series")

    rows = {}
    seen = set()
    for point in series["dataPoints"]:
        if not isinstance(point, dict) or not isinstance(point.get("time"), str):
            raise MetricError("Invalid metric point")
        try:
            stamp = _utc_bucket(datetime.fromisoformat(point["time"].replace("Z", "+00:00")), granularity)
        except (ValueError, OverflowError):
            raise MetricError("Invalid metric bucket timestamp") from None
        if not start <= stamp < end or stamp in seen:
            raise MetricError("Unexpected or repeated metric bucket")
        seen.add(stamp)
        if "status" in point and point["status"] != "Valid":
            continue
        value = point.get("value")
        if value is None:
            continue
        if point.get("stringValues") or type(value) not in (float, int):
            raise MetricError("Expected a numeric metric value")
        try:
            numeric = float(value)
        except OverflowError:
            raise MetricError("Numeric metric value is out of range") from None
        if not math.isfinite(numeric) or numeric < 0:
            raise MetricError("Invalid numeric metric value")
        rows[_iso(stamp)] = numeric
    return rows


def fetch_metric(key: str, universe: str, metric: str, granularity: str,
                 start: datetime, end: datetime) -> dict[str, float]:
    """Return completed numeric buckets in [start, end) keyed by their UTC start."""
    if not re.fullmatch(r"[1-9][0-9]*", universe):
        raise ValueError("Invalid universe ID")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", metric) or granularity not in ("OneHour", "OneDay"):
        raise ValueError("Invalid metric or granularity")
    if not key or not key.isascii() or any(not 32 < ord(ch) < 127 for ch in key):
        raise ValueError("Invalid API key format")
    start, end = _utc_bucket(start, granularity), _utc_bucket(end, granularity)
    if start >= end:
        raise ValueError("Expected a positive query window")

    headers = {"x-api-key": key, "Content-Type": "application/json", "Accept": "application/json"}
    path = f"v1/universes/{universe}/metrics"
    payload = {"metric": metric, "granularity": granularity, "startTime": _iso(start), "endTime": _iso(end)}
    request = Request(BASE + path, data=json.dumps(payload).encode("utf-8"), headers=headers)
    deadline = time.monotonic() + 90
    operation_path = None
    while True:
        envelope = request_json(request, deadline, metric_universe=universe)
        if "error" in envelope:
            error = envelope["error"]
            code = error.get("code") if isinstance(error, dict) else None
            raise MetricError(f"Roblox operation error {code}" if type(code) is int else "Roblox operation error")
        if envelope.get("done") is True:
            return _points(envelope.get("response"), granularity, start, end)
        path = envelope.get("path")
        if (envelope.get("done") is not False or not isinstance(path, str) or
                not re.fullmatch(rf"v1/universes/{universe}/operations/metrics/[A-Za-z0-9_-]+", path) or
                (operation_path is not None and path != operation_path)):
            raise MetricError("Invalid pending Roblox metric operation")
        operation_path = path
        _pause(2, deadline)
        request = Request(BASE + path, headers=headers)
