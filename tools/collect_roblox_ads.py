"""Collect Roblox advertising and experience statistics for BrickToads."""

import os
import re
import sqlite3
import sys
import tempfile
from collections import Counter
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path

from roblox_ads_api import MetricError, MetricUnavailable, fetch_metric
from roblox_ads_report import AD_METRICS, DAU, PEAK, SAMPLED, VISITS, build_report, utc_stamp
from roblox_ads_snapshot import fetch_campaigns, fetch_public


UNIVERSE = "10777822493"
OUTPUT = Path(__file__).resolve().parents[1] / "reports" / "roblox-ads"


def init_db(db):
    db.executescript("""
        CREATE TABLE IF NOT EXISTS metrics (
            granularity TEXT, metric TEXT, bucket TEXT, value REAL NOT NULL,
            PRIMARY KEY (granularity, metric, bucket)
        );
        CREATE TABLE IF NOT EXISTS samples (
            bucket TEXT PRIMARY KEY, observed_at TEXT NOT NULL, playing INTEGER, visits INTEGER
        );
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY, started_at TEXT NOT NULL, status TEXT NOT NULL, report TEXT NOT NULL
        );
    """)


def replace_window(db, granularity, metric, start, end, points):
    db.execute("DELETE FROM metrics WHERE granularity=? AND metric=? AND bucket>=? AND bucket<?",
               (granularity, metric, start, end))
    db.executemany("INSERT INTO metrics VALUES (?, ?, ?, ?)",
                   ((granularity, metric, bucket, value) for bucket, value in points.items()))


def record_sample(db, stamp, sample):
    bucket = stamp[:13] + ":00:00Z"
    db.execute("INSERT INTO samples VALUES (?, ?, ?, ?) ON CONFLICT(bucket) DO NOTHING",
               (bucket, stamp, sample["playing"], sample["visits"]))


def load_window(db, key, granularity, metrics, start, end, notes, failures):
    result = {}
    for metric in metrics:
        try:
            points = fetch_metric(key, UNIVERSE, metric, granularity, start, end)
        except MetricUnavailable:
            notes.append(f"Roblox указывает, что {metric} ({granularity}) недоступна для BrickToads.")
            continue
        except MetricError as error:
            failures.append(f"{metric} ({granularity}) — {error}.")
            continue
        replace_window(db, granularity, metric, utc_stamp(start), utc_stamp(end), points)
        result[metric] = points
    return result


def campaign_summary(campaigns):
    if not campaigns:
        return "Ads Manager вернул пустой список кампаний для BrickToads."
    statuses = Counter(c["deliveryStatus"] for c in campaigns)
    parts = []
    for status, count in sorted(statuses.items()):
        label = status if re.fullmatch(r"[A-Z_]{1,64}", status) else "неизвестный статус"
        parts.append(f"{label} — {count}")
    return f"Кампаний в Ads Manager — {len(campaigns)}. Статусы показа по данным Roblox: " + ", ".join(parts) + "."


def collect(db, key, now):
    notes, failures = [], []
    try:
        public = fetch_public(UNIVERSE)
        observed_at = datetime.now(UTC)
        record_sample(db, utc_stamp(observed_at), public)
        notes.append(f"Замер {observed_at:%Y-%m-%d %H:%M} UTC. Игроков онлайн — {public['playing']}. "
                     f"Посещений за всё время — {public['visits']}.")
    except RuntimeError as error:
        failures.append(f"Публичные счётчики Roblox — {error}.")
    try:
        notes.append(campaign_summary(fetch_campaigns(key, UNIVERSE)))
    except RuntimeError as error:
        failures.append(f"Список кампаний — {error}.")

    hour_end = now.replace(minute=0, second=0, microsecond=0)
    hour_start = hour_end - timedelta(days=7)
    hourly = load_window(db, key, "OneHour", (*AD_METRICS, PEAK), hour_start, hour_end, notes, failures)
    daily_end = hour_end.replace(hour=0)
    daily = load_window(db, key, "OneDay", (*AD_METRICS, DAU, VISITS), daily_end - timedelta(days=28),
                        daily_end, notes, failures)
    hourly[SAMPLED] = dict(db.execute("SELECT bucket, playing FROM samples WHERE bucket>=? AND bucket<?",
                                     (utc_stamp(hour_start), utc_stamp(hour_end))))
    report = build_report(hourly, daily, now)
    report += "\n## Состояние источников\n\n" + "\n".join(f"- {note}" for note in notes) + "\n"
    if failures:
        report += "\n### Ошибки текущего сбора\n\n" + "\n".join(f"- {item}" for item in failures) + "\n"
    status = "partial" if failures else "ok"
    db.execute("INSERT INTO runs (started_at, status, report) VALUES (?, ?, ?)", (utc_stamp(now), status, report))
    return status


def write_latest(db, output):
    # Read and publish under the same lock so overlapping runs cannot publish an older report.
    db.execute("BEGIN IMMEDIATE")
    report, = db.execute("SELECT report FROM runs ORDER BY id DESC LIMIT 1").fetchone()
    with tempfile.NamedTemporaryFile(dir=output, delete=False, mode="w", encoding="utf-8", suffix=".tmp") as f:
        tmp = Path(f.name)
        try:
            f.write(report)
        except BaseException:
            f.close()
            tmp.unlink(missing_ok=True)
            raise
    try:
        tmp.replace(output / "latest.md")
    finally:
        tmp.unlink(missing_ok=True)
    db.commit()


def main():
    key = os.environ.pop("ROBLOX_ANALYTICS_KEY", "").strip()
    if not key or not key.isascii() or any(not 32 < ord(char) < 127 for char in key):
        sys.exit("Invalid or missing Roblox analytics credential.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(OUTPUT / "history.sqlite3", timeout=90)) as db:
        init_db(db)
        with db:
            db.execute("BEGIN IMMEDIATE")
            status = collect(db, key, datetime.now(UTC))
        write_latest(db, OUTPUT)
    print(f"{status}: {OUTPUT / 'latest.md'}")
    return 1 if status == "partial" else 0


if __name__ == "__main__":
    sys.exit(main())
