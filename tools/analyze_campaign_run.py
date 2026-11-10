"""Read recorded Studio campaign JSON; never connect to or change the game.

Usage: python tools/analyze_campaign_run.py ARCHIVE [--out SUMMARY] [--require-won]
Optional: --god-mode-evidence PRESENTATION_JSON for a separately labelled Studio
diagnostic. The default retains finite reserve checks. All six boss encounters
are required for completion in either scope; original finite checks and
violations are always retained separately. No input evidence is changed.
"""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

BOSSES = {1: 'CausewayGuardian', 5: 'BigBlag', 8: 'RoboManus',
          10: 'GeneralSlaughter', 11: 'Buzzball', 13: 'DarkQueen'}
PROGRESS = {'RoboManus', 'GeneralSlaughter', 'DarkQueen'}


def integer(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value) and value == int(value))


def rows(value):
    return [row for row in value if isinstance(row, dict)] if isinstance(value, list) else []


def _summarize_finite(document):
    if not isinstance(document, dict):
        raise ValueError('Archive must be a JSON object')
    stages = rows(document.get('stages'))
    samples = rows(document.get('samples'))
    events = rows(document.get('events'))
    current = document.get('current') if isinstance(document.get('current'), dict) else {}
    expected = list(range(1, 14))
    observed = [row.get('index') for row in stages]
    epochs = [row.get('epoch') for row in stages]
    observed_indexes = sorted({int(index) for index in observed if integer(index)})
    run_ids = [row.get('runId') for row in stages]
    for row in [document, current] + samples:
        if row.get('runId') is not None:
            run_ids.append(row['runId'])
    same_run = bool(stages) and all(isinstance(run, str) and bool(run) for run in run_ids) and len(set(run_ids)) == 1
    raw_stages = document.get('stages')
    checks = {'stage_records': isinstance(raw_stages, list) and len(raw_stages) == 13
                              and all(isinstance(s, dict) for s in raw_stages),
              'stage_sequence': all(integer(index) for index in observed) and observed == expected,
              'epochs': all(integer(epoch) for epoch in epochs) and epochs == expected,
              'same_run': same_run, 'stage_times_nondecreasing': True,
              'fixed_cohort': True, 'fixed_owners': True, 'owners_registered': True,
              'stocks_nonincreasing': True, 'attempts_nondecreasing': True,
              'resource_bounds': True, 'no_resurrection': True}
    violations = []
    limits = ['Resource/cohort checks compare stage-entry and terminal cohort observations; omitted within-level transitions are not independently verified.',
              'Recorded Studio evidence does not establish manual input, genuine-account reconnect, or public-server soak coverage.']

    def fail(check, detail):
        checks[check] = False
        if len(violations) < 20:
            violations.append({'check': check, **detail})

    def unknown(check):
        if checks.get(check) is not False:
            checks[check] = None

    times = [row.get('at') for row in stages]
    if any(not isinstance(at, (int, float)) or isinstance(at, bool) or not math.isfinite(at) for at in times):
        fail('stage_times_nondecreasing', {'reason': 'Stage entries require finite numeric times'})
    elif times != sorted(times):
        fail('stage_times_nondecreasing', {'reason': 'Stage entries move backward in time'})
    first = rows(stages[0].get('cohort')) if stages else []
    slots = sorted({int(row['slot']) for row in first if integer(row.get('slot'))})
    expected_players = document.get('expectedPlayers')
    if not slots:
        checks['fixed_cohort'] = None
    elif integer(expected_players) and len(slots) != expected_players:
        fail('fixed_cohort', {'reason': 'Initial cohort size differs from expectedPlayers'})
    owners, last_stock, last_attempt, eliminated = {}, {}, {}, set()
    snapshots = [('stage-' + str(row.get('index')), rows(row.get('cohort'))) for row in stages]
    terminal = rows(document.get('cohort'))
    snapshots.append(('terminal', terminal))
    for label, cohort in snapshots:
        by_slot = {int(row['slot']): row for row in cohort if integer(row.get('slot'))}
        if not cohort:
            unknown('fixed_cohort')
            for name in ('fixed_owners', 'stocks_nonincreasing', 'attempts_nondecreasing', 'resource_bounds', 'no_resurrection'):
                unknown(name)
            continue
        if sorted(by_slot) != slots or len(by_slot) != len(cohort):
            fail('fixed_cohort', {'observation': label, 'slots': sorted(by_slot)})
        for slot, row in by_slot.items():
            owner = row.get('ownerUserId')
            if not integer(owner):
                unknown('fixed_owners')
            elif slot in owners and owners[slot] != owner:
                fail('fixed_owners', {'observation': label, 'slot': slot, 'previous': owners[slot], 'owner': owner})
            else:
                owners.setdefault(slot, int(owner))
            stock, attempt, status = row.get('stock'), row.get('attempt'), row.get('status')
            if not integer(stock) or not integer(attempt):
                for name in ('resource_bounds', 'stocks_nonincreasing', 'attempts_nondecreasing'):
                    unknown(name)
            else:
                if not 0 <= stock <= 3 or not 1 <= attempt <= 4:
                    fail('resource_bounds', {'observation': label, 'slot': slot, 'stock': stock, 'attempt': attempt})
                if slot in last_stock and stock > last_stock[slot]:
                    fail('stocks_nonincreasing', {'observation': label, 'slot': slot, 'previous': last_stock[slot], 'stock': stock})
                if slot in last_attempt and attempt < last_attempt[slot]:
                    fail('attempts_nondecreasing', {'observation': label, 'slot': slot, 'previous': last_attempt[slot], 'attempt': attempt})
                last_stock[slot], last_attempt[slot] = stock, attempt
            if not isinstance(status, str):
                unknown('no_resurrection')
            elif slot in eliminated and status != 'Eliminated':
                fail('no_resurrection', {'observation': label, 'slot': slot, 'status': status})
            if status == 'Eliminated':
                eliminated.add(slot)
    if len(set(owners.values())) != len(owners):
        fail('fixed_owners', {'reason': 'Multiple slots use one owner identity'})
    registered = {int(row['userId']) for row in rows(document.get('registeredPlayers')) if integer(row.get('userId'))}
    if not registered or len(owners) != len(slots):
        checks['owners_registered'] = None
    elif not set(owners.values()).issubset(registered):
        fail('owners_registered', {'reason': 'Cohort owner is absent from registeredPlayers'})
    if checks['fixed_owners'] is None:
        limits.append('At least one stage/terminal ownerUserId is missing; owner stability is unverified.')

    run_results = [event.get('data', {}).get('result') for event in events if event.get('kind') == 'RunResult' and isinstance(event.get('data'), dict)]
    reported = document.get('result')
    checks.update({'terminal_won': reported == 'Won', 'run_result_won_event': 'Won' in run_results,
                   'terminal_result_consistent': bool(run_results) and set(run_results) == {reported},
                   'terminal_index_13': current.get('index') == 13 and current.get('epoch') == 13,
                   'terminal_live_survivor': any(row.get('status') == 'Alive' for row in terminal),
                   'no_reported_errors': isinstance(document.get('errors'), list) and not document['errors']})
    completions = sorted({int(event['data']['index']) for event in events
                          if event.get('kind') == 'CampaignStageCompleted' and isinstance(event.get('data'), dict)
                          and integer(event['data'].get('index'))})
    checks['stage_completion_events'] = completions == list(range(1, 13))
    if not events:
        limits.append('No retained events supplied; terminal and boss event evidence is unavailable.')
    if document.get('sampleSelection'):
        limits.append('Samples were thinned: ' + str(document['sampleSelection']))
    if document.get('eventSeqGaps') or document.get('missedSeqRanges'):
        limits.append('Archive reports journal sequence gaps; event coverage is incomplete.')

    boss_rows = {}
    for level, kind in BOSSES.items():
        boss_rows[level] = {'level': level, 'kind': kind, 'phases_seen': set(), 'states_seen': set(),
                            'raw_life_min': None, 'progress_max': None, 'underflows_seen': 0,
                            'defeated_event_seen': False, 'guardian_hits_max': 0}

    def number_observed(row, key, value, maximum=False):
        if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
            old = row[key]
            row[key] = value if old is None else max(old, value) if maximum else min(old, value)

    def phase_for(kind, raw, progress):
        if kind in PROGRESS and isinstance(progress, (int, float)):
            return 2 if progress >= 120 else 1
        if isinstance(raw, (int, float)):
            if kind == 'BigBlag':
                return 1 if raw >= 192 else 2 if raw >= 128 else 3
            if kind == 'Buzzball':
                return 1 if raw >= 128 else 2
        return None

    for sample in samples + [current]:
        level = sample.get('index')
        if level not in boss_rows:
            continue
        row = boss_rows[level]
        if level == 1:
            row['guardian_hits_max'] = max(row['guardian_hits_max'], sample.get('guardianHits') or 0)
        boss = sample.get('boss')
        if not isinstance(boss, dict):
            continue
        raw = boss.get('bossRawLife', boss.get('rawLife'))
        progress = boss.get('bossProgress', boss.get('progress'))
        phase = boss.get('bossPhase') or phase_for(row['kind'], raw, progress)
        if integer(phase):
            row['phases_seen'].add(int(phase))
        if isinstance(boss.get('bossState'), str):
            row['states_seen'].add(boss['bossState'])
        number_observed(row, 'raw_life_min', raw)
        number_observed(row, 'progress_max', progress, True)
    epoch_levels = {stage.get('epoch'): stage.get('index') for stage in stages}
    by_kind = {kind: level for level, kind in BOSSES.items()}
    for event in events:
        data = event.get('data') if isinstance(event.get('data'), dict) else {}
        level = by_kind.get(data.get('bossType'), epoch_levels.get(event.get('levelEpoch')))
        if level not in boss_rows:
            continue
        row = boss_rows[level]
        if level == 1 and event.get('kind') == 'BossHit':
            row['guardian_hits_max'] = max(row['guardian_hits_max'], data.get('hits') or 0)
        if not str(event.get('kind', '')).startswith('CampaignBoss'):
            continue
        phase = data.get('phase') or phase_for(row['kind'], data.get('before'), data.get('progress'))
        if integer(phase):
            row['phases_seen'].add(int(phase))
        number_observed(row, 'raw_life_min', data.get('after'))
        number_observed(row, 'progress_max', data.get('progress'), True)
        if event.get('kind') == 'CampaignBossHit' and data.get('underflow') is True:
            row['underflows_seen'] += 1
        if event.get('kind') == 'CampaignBossDefeated':
            row['defeated_event_seen'] = True
    for level, row in boss_rows.items():
        kind = row['kind']
        wanted = [1, 2, 3] if kind == 'BigBlag' else [] if level == 1 else [1, 2]
        row['phases_seen'] = sorted(row['phases_seen'])
        row['states_seen'] = sorted(row['states_seen'])
        row['expected_phases'] = wanted
        row['complete_evidence'] = (row['guardian_hits_max'] >= 3 if level == 1 else
                                    set(wanted).issubset(row['phases_seen']) and row['defeated_event_seen']
                                    and (kind not in PROGRESS or (row['progress_max'] or 0) >= 240 and row['underflows_seen'] >= 21))
    checks['boss_evidence_complete'] = all(row['complete_evidence'] for row in boss_rows.values())
    if not checks['boss_evidence_complete']:
        limits.append('Incomplete boss observation coverage is not evidence of an unplayed phase; omitted payloads/sparse samples cannot prove those phases.')
    core = [name for name in checks if name != 'boss_evidence_complete']
    complete = all(checks[name] is True for name in core)
    return {'reported_result': reported, 'complete_won': complete,
            'all_requested_checks_pass': complete and checks['boss_evidence_complete'],
            'run_id': run_ids[0] if same_run else None, 'observed_stages': observed_indexes,
            'missing_stages': [index for index in expected if index not in observed_indexes],
            'checks': checks, 'cohort': {'slots': slots, 'owners_by_slot': owners, 'terminal': terminal},
            'stage_completion_events': completions, 'bosses': list(boss_rows.values()),
            'sample_count_supplied': len(samples), 'event_count_supplied': len(events),
            'violations': violations, 'limits': limits}


def _god_enabled(value):
    return (isinstance(value, dict) and value.get('attribute') is True
            and value.get('configured') is True and value.get('allowed') is True
            and integer(value.get('infiniteHeroes')) and value['infiniteHeroes'] > 0)


def _verify_god_evidence(document, finite, evidence):
    """Validate the native observer's run/build and every recorded stage policy.

    This is sampled evidence, not proof of continuous toggles between observations.
    It grants only the explicit unlimited-attempt diagnostic scope.
    """
    evidence = evidence if isinstance(evidence, dict) else {}
    source = document.get('build')
    source_valid = isinstance(source, str) and re.fullmatch(r'[0-9a-f]{64}', source) is not None
    stages = rows(evidence.get('stages'))
    expected = list(range(1, 14))
    proof_errors = evidence.get('errors')
    raw_stages = evidence.get('stages')
    checks = {
        'same_run': bool(finite['run_id']) and evidence.get('runId') == finite['run_id'],
        'same_source': source_valid and evidence.get('observedSourceSha256') == source
                       and evidence.get('expectedSourceSha256') == source and evidence.get('sourceMatches') is True,
        'stage_records': isinstance(raw_stages, list) and len(raw_stages) == 13
                         and all(isinstance(s, dict) for s in raw_stages),
        'stage_sequence': all(integer(s.get('index')) for s in stages) and [s.get('index') for s in stages] == expected,
        'epochs': all(integer(s.get('epoch')) for s in stages) and [s.get('epoch') for s in stages] == expected,
        'observed_all_stages': len(stages) == 13 and all(integer(s.get('observations')) and s['observations'] > 0 for s in stages),
        'every_stage_god_mode': len(stages) == 13 and all(_god_enabled(s.get('godMode')) for s in stages),
        'terminal_god_mode': _god_enabled(evidence.get('godMode')),
        'observer_without_errors': isinstance(proof_errors, list) and not proof_errors,
    }
    verified = [s['index'] for s in stages if integer(s.get('index')) and 1 <= s['index'] <= 13
                and s.get('epoch') == s['index'] and integer(s.get('observations')) and s['observations'] > 0
                and _god_enabled(s.get('godMode'))]
    return {'valid': all(checks.values()), 'checks': checks, 'run_id': evidence.get('runId'),
            'observed_source_sha256': evidence.get('observedSourceSha256'),
            'verified_stages': sorted(set(verified)),
            'violations': [{'check': 'god_mode_evidence', 'reason': name} for name, passed in checks.items() if not passed],
            'limits': ['God Mode is recorded at stage observations and terminal capture; unsampled policy changes are not reconstructed.',
                       'Positive infiniteHeroes proves at least one enabled hero, not individual per-slot enablement in a multiplayer cohort.']}


def _god_resource_bounds(document):
    """Relax only the finite appearance upper bound, retaining every other bound."""
    state = True
    violations = []
    snapshots = [('stage-' + str(s.get('index')), rows(s.get('cohort'))) for s in rows(document.get('stages'))]
    snapshots.append(('terminal', rows(document.get('cohort'))))
    for label, cohort in snapshots:
        if not cohort and state is not False:
            state = None
        for hero in cohort:
            stock, attempt = hero.get('stock'), hero.get('attempt')
            if not integer(stock) or not integer(attempt):
                if state is not False:
                    state = None
            elif not 0 <= stock <= 3 or attempt < 1:
                state = False
                if len(violations) < 20:
                    violations.append({'check': 'resource_bounds', 'observation': label,
                                       'slot': hero.get('slot'), 'stock': stock, 'attempt': attempt})
    return state, violations


def summarize(document, god_mode_evidence=None):
    finite = _summarize_finite(document)
    result = dict(finite)
    result.update({'completion_scope': 'finite_reserves',
                   'finite_checks': dict(finite['checks']), 'finite_violations': list(finite['violations']),
                   'finite_complete_won': finite['complete_won'],
                   'finite_all_requested_checks_pass': finite['all_requested_checks_pass'],
                   'finite_reserve_acceptance': finite['all_requested_checks_pass']})
    checks = dict(finite['checks'])
    violations = list(finite['violations'])
    if god_mode_evidence is not None:
        proof = _verify_god_evidence(document, finite, god_mode_evidence)
        result['completion_scope'] = 'studio_god_mode_diagnostic'
        result['finite_reserve_acceptance'] = False
        result['god_mode_evidence'] = proof
        checks['god_mode_evidence_valid'] = proof['valid']
        if proof['valid']:
            checks['resource_bounds'], resource_violations = _god_resource_bounds(document)
            violations = [v for v in violations if v['check'] != 'resource_bounds'] + resource_violations
        else:
            violations += proof['violations']
        result['limits'] = finite['limits'] + [
            'Studio God Mode diagnostic completion does not establish finite reserve acceptance. Only the attempt upper bound is relaxed.',
            *proof['limits']]
    # Unlike the legacy report's core-only complete_won, this durable analyzer
    # requires every retained boss-phase check for the requested completion.
    complete = all(value is True for value in checks.values())
    result.update({'checks': checks, 'violations': violations,
                   'complete_won': complete, 'all_requested_checks_pass': complete})
    return result


def _load(path):
    source = path.read_bytes()
    value = json.loads(source)
    while isinstance(value, str):
        value = json.loads(value)
    return value, {'path': str(path.resolve()), 'bytes': len(source), 'sha256': hashlib.sha256(source).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--require-won', action='store_true')
    parser.add_argument('--god-mode-evidence', type=Path,
                        help='Native presentation observer JSON proving God Mode for the same run/build and all13 stages')
    args = parser.parse_args()
    protected = [args.archive, *([args.god_mode_evidence] if args.god_mode_evidence else [])]
    if args.out and args.out.resolve() in [p.resolve() for p in protected]:
        parser.error('--out must not overwrite either input evidence file')
    try:
        value, receipt = _load(args.archive)
        proof, proof_receipt = _load(args.god_mode_evidence) if args.god_mode_evidence else (None, None)
        if args.god_mode_evidence and proof is None:
            proof = {}  # An explicitly supplied JSON null is failed proof, not the default finite mode.
        result = summarize(value, proof)
    except (OSError, ValueError, TypeError) as exc:
        parser.error(str(exc))
    result['source'] = receipt
    if proof_receipt:
        result['god_mode_evidence']['source'] = proof_receipt
    encoded = json.dumps(result, separators=(',', ':'), ensure_ascii=True)
    if args.out:
        args.out.write_text(encoded + '\n', encoding='utf-8')
    print(encoded)
    return 1 if args.require_won and not result['complete_won'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
