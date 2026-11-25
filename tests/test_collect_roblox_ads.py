import sqlite3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from collect_roblox_ads import init_db, record_sample, replace_window


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        init_db(self.db)

    def test_requery_replaces_corrected_and_withdrawn_points_only_inside_window(self):
        start = "2026-11-17T01:00:00Z"
        end = "2026-11-17T03:00:00Z"
        older = "2026-11-17T00:00:00Z"
        dropped = "2026-11-17T02:00:00Z"
        replace_window(self.db, "OneHour", "SponsoredAdsClicks", older, end,
                       {older: 7, start: 5, dropped: 2})
        replace_window(self.db, "OneHour", "SponsoredAdsClicks", start, end, {start: 3})
        result = dict(self.db.execute("SELECT bucket, value FROM metrics"))
        self.assertEqual(result, {older: 7, start: 3})

    def test_repeat_collection_keeps_first_sample_for_hour(self):
        record_sample(self.db, "2026-11-19T13:42:01Z", {"playing": 4, "visits": 10})
        record_sample(self.db, "2026-11-19T13:55:14Z", {"playing": 8, "visits": 12})
        row = self.db.execute("SELECT bucket, observed_at, playing, visits FROM samples").fetchone()
        self.assertEqual(row, ("2026-11-19T13:00:00Z", "2026-11-19T13:42:01Z", 4, 10))
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM samples").fetchone()[0], 1)
