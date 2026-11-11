"""Run production menu policy and actual layout functions in Luau, without Studio.

Only Roblox GUI value/Instance surfaces are adapted. No copied presentation or
layout decisions are used: every function is embedded from the production file.
"""
from pathlib import Path
import argparse
import shutil
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUAU = str(ROOT / '.tools/luau-0.745/luau.exe')


def module(path):
    return '(function()\n' + (ROOT / path).read_text(encoding='utf8') + '\nend)()'


def bundle(client_source=None):
    client = client_source or (ROOT / 'src/client/BrickToadsClient.client.luau').read_text(encoding='utf8')
    menu = client.split('render = function()\n', 1)[1].split('    renderSelection()\n', 1)[0]
    layout = client.split('layout = function()\n', 1)[1].split('\nlocal function dragCameraTo', 1)[0]
    audio = client.split('local function layoutAudioSettings(', 1)[1].split('-- Audio controls: end', 1)[0]
    resources = client.split('render = function()\n', 1)[1].split('    local enemy = snapshot and snapshot.enemyRole\n', 1)[1]
    resources = '    local enemy = snapshot and snapshot.enemyRole\n' + resources.split('    local interaction = snapshot and snapshot.interaction\n', 1)[0]
    health = client.split('local function visualHealth(', 1)[1].split('local function campaignDetail(', 1)[0]
    mobile = client.split('local function renderMobileSummary(', 1)[1].split('render = function()\n', 1)[0]
    portrait = client.split('local function toadPortrait(', 1)[1].split('for i, template in ipairs(templates)', 1)[0]
    notices = client.split('local noticeMessages = {', 1)[1].split('\n}', 1)[0]
    names = re.findall(r'local (\w+) = (?:frame|label|button|make)\(', client)
    anchors = [line.strip() for line in client.split('layout = function()\n', 1)[0].splitlines()
               if 'AnchorPoint' in line and line.strip().split('.', 1)[0] in names]
    policy = ROOT / 'src/client/CampaignPresentation.luau'
    prelude = (ROOT / 'tests/ReleaseUI.fixture.luau').read_text(encoding='utf8')
    return '\n'.join([
        prelude,
        'local Catalog=' + module('src/shared/TextCatalog.luau'),
        'local Localization=' + module('src/shared/TextLocalization.luau'),
        'local BossQueuePanel=' + module('src/client/BossQueuePanel.luau'),
        'local GroupPanel=' + module('src/client/GroupPanel.luau'),
        'CampaignPresentation=' + (module('src/client/CampaignPresentation.luau') if policy.exists() else '{}'),
        '\n'.join(name + '=node("' + name + '")' for name in sorted(set(names))),
        '\n'.join(anchors),
        'noticeMessages={' + notices + '\n}',
        'function productionMenu()\n' + menu + '\nend',
        'function visualHealth(' + health,
        'function productionResources()\n' + resources + '\nend',
        'function renderMobileSummary(' + mobile,
        'function toadPortrait(' + portrait,
        'function layoutAudioSettings(' + audio,
        'function productionLayout()\n' + layout,
        'local specs=' + module('tests/ReleaseUI.spec.luau'),
        'specs(Catalog,Localization,BossQueuePanel,GroupPanel)',
    ])


class ReleaseUI(unittest.TestCase):
    def test_production_menu_and_hit_rectangles(self):
        exe = LUAU
        self.assertTrue(Path(exe).exists() or shutil.which(exe), 'Luau 0.745 is required for behavioral UI checks')
        with tempfile.TemporaryDirectory(dir=ROOT / 'build', prefix='release-ui-') as folder:
            script = Path(folder) / 'run.luau'
            script.write_text(bundle(), encoding='utf8')
            result = subprocess.run([str(exe), str(script)], cwd=ROOT, text=True,
                                    encoding='utf8', stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--luau', default=LUAU)
    options, rest = parser.parse_known_args()
    LUAU = options.luau
    unittest.main(argv=[__file__, *rest])
