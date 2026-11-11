"""Recorded-run and adversarial policy checks for the read-only campaign analyzer."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools/analyze_campaign_run.py'
NATIVE25 = ROOT / 'reports/2026-11-10-full-campaign-playthrough/attempt-25-full-natural-archive.json'
NATIVE26 = ROOT / 'reports/2026-11-11-full-campaign-cast-audio/attempt26-terminal-archive.json'
PROOF26 = NATIVE26.with_name('attempt26-presentation.json')


def read_json(path):
    value = json.loads(path.read_bytes())
    while isinstance(value, str):
        value = json.loads(value)
    return value


class CampaignRunTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not TOOL.is_file():
            raise AssertionError('RED: durable tools/analyze_campaign_run.py is missing')
        spec = importlib.util.spec_from_file_location('campaign_run_analyzer', TOOL)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)
        cls.native25 = read_json(NATIVE25)
        cls.native26 = read_json(NATIVE26)
        cls.proof26 = read_json(PROOF26)

    def analyze(self, value=None, proof=None):
        return self.module.summarize(self.native26 if value is None else value, proof)

    def test_native25_retains_strict_finite_acceptance(self):
        result = self.analyze(self.native25)
        self.assertTrue(result['complete_won'])
        self.assertTrue(result['finite_reserve_acceptance'])
        self.assertTrue(result['all_requested_checks_pass'])
        self.assertEqual(result['checks'], result['finite_checks'])
        self.assertEqual(result['finite_violations'], [])
        self.assertEqual(result['completion_scope'], 'finite_reserves')

    def test_native26_stays_finite_negative_without_explicit_proof(self):
        result = self.analyze()
        self.assertFalse(result['complete_won'])
        self.assertFalse(result['finite_reserve_acceptance'])
        self.assertFalse(result['checks']['resource_bounds'])
        self.assertTrue(result['checks']['boss_evidence_complete'])
        self.assertEqual(result['violations'], result['finite_violations'])
        self.assertTrue(any(v['check'] == 'resource_bounds' for v in result['finite_violations']))

    def test_native26_verified_god_mode_is_explicit_diagnostic_completion(self):
        result = self.analyze(proof=self.proof26)
        self.assertTrue(result['complete_won'])
        self.assertTrue(result['all_requested_checks_pass'])
        self.assertFalse(result['finite_reserve_acceptance'])
        self.assertEqual(result['completion_scope'], 'studio_god_mode_diagnostic')
        self.assertTrue(result['checks']['resource_bounds'])
        self.assertFalse(result['finite_checks']['resource_bounds'])
        self.assertTrue(result['finite_violations'])
        self.assertEqual(result['violations'], [])
        self.assertTrue(result['god_mode_evidence']['valid'])
        self.assertEqual(result['god_mode_evidence']['verified_stages'], list(range(1, 14)))

    def test_wrong_run_source_and_errorful_proof_reject(self):
        for field, value in [('runId', 'another-run'), ('observedSourceSha256', '0' * 64),
                             ('expectedSourceSha256', '0' * 64), ('sourceMatches', False),
                             ('errors', [{'error': 'observer failed'}])]:
            with self.subTest(field=field):
                proof = copy.deepcopy(self.proof26)
                proof[field] = value
                result = self.analyze(proof=proof)
                self.assertFalse(result['complete_won'])
                self.assertFalse(result['god_mode_evidence']['valid'])
                self.assertFalse(result['finite_reserve_acceptance'])

    def test_incomplete_duplicate_or_wrong_epoch_stage_proof_rejects(self):
        for mutation in ['Missing', 'Duplicate', 'Epoch', 'NoObservations', 'JunkRecord', 'BooleanIndex']:
            with self.subTest(mutation=mutation):
                proof = copy.deepcopy(self.proof26)
                if mutation == 'Missing':
                    proof['stages'].pop()
                elif mutation == 'Duplicate':
                    proof['stages'][4]['index'] = 4
                elif mutation == 'Epoch':
                    proof['stages'][4]['epoch'] = 1
                elif mutation == 'NoObservations':
                    proof['stages'][4]['observations'] = 0
                elif mutation == 'JunkRecord':
                    proof['stages'].append(None)
                else:
                    proof['stages'][0]['index'] = True
                self.assertFalse(self.analyze(proof=proof)['complete_won'])

    def test_each_stage_requires_actual_true_god_flags_and_positive_count(self):
        for index in range(13):
            for key, value in [('attribute', False), ('configured', False), ('allowed', False),
                               ('infiniteHeroes', 0), ('infiniteHeroes', True)]:
                with self.subTest(stage=index + 1, field=key, value=value):
                    proof = copy.deepcopy(self.proof26)
                    proof['stages'][index]['godMode'][key] = value
                    self.assertFalse(self.analyze(proof=proof)['complete_won'])

    def test_missing_or_false_terminal_god_proof_rejects(self):
        for value in [{}, None, {'attribute': True, 'configured': False, 'allowed': True, 'infiniteHeroes': 1}]:
            proof = copy.deepcopy(self.proof26)
            proof['godMode'] = value
            self.assertFalse(self.analyze(proof=proof)['complete_won'])
        self.assertFalse(self.analyze(proof={})['complete_won'])

    def test_god_scope_retains_all_other_campaign_and_cohort_checks(self):
        mutations = {
            'same_run': lambda d: d['stages'][4].update(runId='other'),
            'stage_sequence': lambda d: d['stages'][4].update(index=7),
            'epochs': lambda d: d['stages'][4].update(epoch=6),
            'fixed_owners': lambda d: d['stages'][4]['cohort'][0].update(ownerUserId=999),
            'owners_registered': lambda d: d.update(registeredPlayers=[{'userId': 999}]),
            'stocks_nonincreasing': lambda d: d['stages'][3]['cohort'][0].update(stock=2),
            'attempts_nondecreasing': lambda d: d['stages'][3]['cohort'][0].update(attempt=3),
            'no_resurrection': lambda d: d['stages'][3]['cohort'][0].update(status='Eliminated'),
            'no_reported_errors': lambda d: d.update(errors=['planner failure']),
            'run_result_won_event': lambda d: d.update(events=[e for e in d['events'] if e['kind'] != 'RunResult']),
        }
        for check, mutate in mutations.items():
            with self.subTest(check=check):
                archive = copy.deepcopy(self.native26)
                mutate(archive)
                result = self.analyze(archive, self.proof26)
                self.assertIsNot(result['checks'][check], True)
                self.assertFalse(result['complete_won'])

    def test_god_scope_keeps_stock_and_positive_integer_attempt_bounds(self):
        for change in [{'attempt': 0}, {'attempt': True}, {'attempt': 1.5}, {'stock': -1}, {'stock': 4}]:
            with self.subTest(change=change):
                archive = copy.deepcopy(self.native26)
                archive['cohort'][0].update(change)
                result = self.analyze(archive, self.proof26)
                self.assertIsNot(result['checks']['resource_bounds'], True)
                self.assertFalse(result['complete_won'])

    def test_six_boss_encounters_remain_required_in_both_scopes(self):
        for archive, proof in [(self.native25, None), (self.native26, self.proof26)]:
            broken = copy.deepcopy(archive)
            broken['samples'] = []
            broken['events'] = [e for e in broken['events'] if not e['kind'].startswith('CampaignBoss')]
            result = self.analyze(broken, proof)
            self.assertFalse(result['checks']['boss_evidence_complete'])
            self.assertFalse(result['complete_won'])

    def test_malformed_archive_stages_and_nonfinite_times_cannot_validate(self):
        for mutation in ['BooleanIndex', 'BooleanEpoch', 'JunkStage', 'NaNTime', 'BooleanTime']:
            with self.subTest(mutation=mutation):
                archive = copy.deepcopy(self.native26)
                if mutation == 'BooleanIndex':
                    archive['stages'][0]['index'] = True
                elif mutation == 'BooleanEpoch':
                    archive['stages'][0]['epoch'] = True
                elif mutation == 'JunkStage':
                    archive['stages'].append(None)
                elif mutation == 'NaNTime':
                    archive['stages'][0]['at'] = float('nan')
                else:
                    archive['stages'][0]['at'] = True
                self.assertFalse(self.analyze(archive, self.proof26)['complete_won'])

    def test_analyzer_never_mutates_input_evidence(self):
        archive, proof = copy.deepcopy(self.native26), copy.deepcopy(self.proof26)
        self.analyze(archive, proof)
        self.assertEqual(archive, self.native26)
        self.assertEqual(proof, self.proof26)

    def test_cli_requires_explicit_proof_and_reports_source_receipts(self):
        command = [sys.executable, str(TOOL), str(NATIVE26), '--require-won']
        strict = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(strict.returncode, 1, strict.stderr)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'summary.json'
            scoped = subprocess.run(command + ['--god-mode-evidence', str(PROOF26), '--out', str(output)], capture_output=True, text=True)
            self.assertEqual(scoped.returncode, 0, scoped.stderr)
            result = read_json(output)
            self.assertFalse(result['finite_reserve_acceptance'])
            self.assertEqual(result['source']['bytes'], NATIVE26.stat().st_size)
            self.assertEqual(result['god_mode_evidence']['source']['bytes'], PROOF26.stat().st_size)
            missing = subprocess.run(command + ['--god-mode-evidence', str(Path(directory) / 'absent.json')], capture_output=True, text=True)
            self.assertNotEqual(missing.returncode, 0)
            invalid = Path(directory) / 'null-proof.json'
            invalid.write_text('null', encoding='utf-8')
            rejected = subprocess.run([sys.executable, str(TOOL), str(NATIVE25), '--require-won',
                                       '--god-mode-evidence', str(invalid)], capture_output=True, text=True)
            self.assertEqual(rejected.returncode, 1, rejected.stderr)
            self.assertFalse(json.loads(rejected.stdout)['god_mode_evidence']['valid'])


if __name__ == '__main__':
    unittest.main()
