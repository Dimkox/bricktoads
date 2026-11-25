import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import roblox_ads_snapshot as snapshot


class SnapshotTests(unittest.TestCase):
    def test_empty_page_can_have_another_page(self):
        campaign = {"id": "a", "targetUniverseId": "42", "name": "Launch",
                    "deliveryStatus": "SERVING", "budget": {"private": 10}}
        with patch.object(snapshot, "request_json", side_effect=[
            {"nextPageToken": "page+/="}, {"campaigns": [campaign]},
        ]) as get_json:
            self.assertEqual(snapshot.fetch_campaigns("test", "42"), [
                {"id": "a", "name": "Launch", "deliveryStatus": "SERVING"}
            ])
        request = get_json.call_args_list[-1].args[0]
        self.assertEqual(request.get_method(), "GET")
        self.assertEqual(request.get_header("X-api-key"), "test")
        self.assertEqual(parse_qs(urlsplit(request.full_url).query), {
            "pageToken": ["page+/="], "maxPageSize": ["100"], "targetUniverseIds": ["42"]
        })

    def test_repeated_page_and_wrong_game_fail(self):
        for pages in ([{"nextPageToken": "x"}] * 2,
                      [{"campaigns": [{"id": "a", "targetUniverseId": "8"}]}]):
            with self.subTest(pages=pages), patch.object(snapshot, "request_json", side_effect=pages):
                with self.assertRaises(RuntimeError):
                    snapshot.fetch_campaigns("test", "42")

    def test_public_counts_without_auth(self):
        with patch.object(snapshot, "request_json",
                          return_value={"data": [{"id": 42, "visits": 3, "playing": 0}]}) as get_json:
            self.assertEqual(snapshot.fetch_public("42"), {"playing": 0, "visits": 3})
        self.assertFalse(get_json.call_args.args[0].has_header("X-api-key"))

    def test_missing_game_or_missing_count_is_not_zero(self):
        for rows in ([], [{"id": 21, "playing": 0, "visits": 1}],
                     [{"id": 42, "visits": 3}], [{"id": 42, "visits": 3, "playing": True}]):
            with self.subTest(rows=rows), patch.object(snapshot, "request_json", return_value={"data": rows}):
                with self.assertRaises(RuntimeError):
                    snapshot.fetch_public("42")
