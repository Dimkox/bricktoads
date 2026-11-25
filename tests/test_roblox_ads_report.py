import unittest
from datetime import datetime, timedelta, timezone

from tools.roblox_ads_report import build_report


NOW = datetime(2026, 11, 19, 18, 15, tzinfo=timezone(timedelta(hours=3)))
HOUR = datetime(2026, 11, 19, 15, tzinfo=timezone.utc)
DAY = HOUR.replace(hour=0)


def stamp(when):
    return when.strftime("%Y-%m-%dT%H:%M:%SZ")


def series(end, step, values):
    return {stamp(end - i * step): value for i, value in enumerate(values, start=1)}


class AdsReportTests(unittest.TestCase):
    def test_stale_joint_hour_does_not_hide_partial_latest_hour(self):
        latest = stamp(HOUR - timedelta(hours=1))
        prior = stamp(HOUR - timedelta(hours=2))
        hourly = {
            "SponsoredAdsImpressions": {prior: 200, latest: 0, stamp(HOUR): 777777},
            "SponsoredAdsClicks": {prior: 4, latest: 0},
            "SponsoredAdsSpendUsd": {prior: 1.50},
            "PeakConcurrentPlayers": {latest: 2},
        }
        report = build_report(hourly, {}, NOW)
        self.assertIn("| 2026-11-19 14:00 | 0 | 0 | — | — | — | 2 |", report)
        self.assertIn("| 2026-11-19 13:00 | 200 | 4 | 1,50 | 2,00% | 0,3750 | — |", report)
        self.assertNotIn("777777", report)

    def test_join_uses_exact_intersection_not_ordinal_positions(self):
        hour = timedelta(hours=1)
        ads = series(HOUR, hour, range(1, 28))
        peak = series(HOUR, hour, (40 - i for i in range(1, 28)))
        del ads[stamp(HOUR - 2 * hour)]
        del peak[stamp(HOUR - 5 * hour)]
        # An old, high-leverage point must never enter the seven-day window.
        ads[stamp(HOUR - 169 * hour)] = peak[stamp(HOUR - 169 * hour)] = 1e7
        result = build_report({"SponsoredAdsClicks": ads, "PeakConcurrentPlayers": peak}, {}, NOW)
        self.assertIn("| Клики | Пиковый онлайн | 25 | -1,000 |", result)

    def test_hourly_samples_remain_separate_from_hourly_peak(self):
        hour = timedelta(hours=1)
        clicks = series(HOUR, hour, range(24))
        samples = series(HOUR, hour, range(24))
        peaks = series(HOUR, hour, [30] * 4)
        hourly = {"SponsoredAdsClicks": clicks, "PeakConcurrentPlayers": peaks,
                  "ObservedConcurrentPlayers": samples}
        report = build_report(hourly, {}, NOW)
        self.assertIn("| Клики | Пиковый онлайн | 4 | Мало данных (минимум 24) |", report)
        self.assertIn("| Клики | Онлайн в момент замера | 24 | 1,000 |", report)

    def test_daily_current_bucket_is_excluded_and_constants_are_explicit(self):
        day = timedelta(days=1)
        visits = series(DAY, day, range(1, 8))
        visits[stamp(DAY)] = 555555
        spend = series(DAY, day, [0] * 7)
        clicks = series(DAY, day, range(1, 7))
        daily = {"Visits": visits, "SponsoredAdsSpendUsd": spend, "SponsoredAdsClicks": clicks}
        result = build_report({}, daily, NOW)
        self.assertIn("| Расход | Сеансы | 7 | Постоянный ряд |", result)
        self.assertIn("| Клики | Сеансы | 6 | Мало данных (минимум 7) |", result)
        self.assertNotIn("555555", result)

    def test_empty_and_nonfinite_observations_are_missing(self):
        prior = stamp(HOUR - timedelta(hours=1))
        report = build_report({"SponsoredAdsClicks": {prior: float("nan")}}, {}, NOW)
        self.assertIn("| 2026-11-19 14:00 | — | — | — | — | — | — |", report)
        self.assertIn("| Клики | Пиковый онлайн | 0 | Нет общих наблюдений |", report)
        self.assertNotIn("nan", report)


if __name__ == "__main__":
    unittest.main()
