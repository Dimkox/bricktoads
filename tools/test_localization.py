"""Production text coverage; native adapter and translated formats run in run_localization.luau."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
QUOTED = r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
TOKENS = re.compile(r'--\[\[.*?\]\]|--[^\n]*|'+QUOTED, re.S)
CYRILLIC = re.compile('[А-Яа-яЁё]')


class LocalizationCoverage(unittest.TestCase):
    def test_english_is_the_source_language_for_all_gameplay_text(self):
        for folder in ('src/client', 'src/server/gameplay', 'src/shared'):
            for path in (ROOT / folder).rglob('*'):
                if path.suffix not in ('.lua', '.luau') or path.name == 'TextCatalog.luau':
                    continue
                for token in TOKENS.finditer(path.read_text(encoding='utf8')):
                    literal = token.group()
                    if not literal.startswith('--'):
                        self.assertIsNone(CYRILLIC.search(literal), f'{path.relative_to(ROOT)}: {literal}')

    def test_legacy_metadata_match_stays_compatible(self):
        # This persisted value identifies an old saved preview; it is never rendered.
        entry = (ROOT / 'src/server/BrickToadsServer.server.luau').read_text(encoding='utf8')
        self.assertIn("legacy:GetAttribute('LevelName')=='Затопленный тракт'", entry)

    def test_explicit_dynamic_ui_sources_have_catalog_entries(self):
        catalog = (ROOT / 'src/shared/TextCatalog.luau').read_text(encoding='utf8')
        keys = {json.loads(match.group(1)) for match in re.finditer(r'Key=("(?:\\.|[^"\\])*")', catalog)}
        count = 0
        for path in (ROOT / 'src/client').glob('*.luau'):
            for match in re.finditer(r'\bT\(("(?:\\.|[^"\\])*")', path.read_text(encoding='utf8')):
                source = json.loads(match.group(1))
                self.assertIn(source, keys, f'{path.name}: {source}')
                count += 1
        self.assertGreaterEqual(count, 35)


if __name__ == '__main__':
    unittest.main()
