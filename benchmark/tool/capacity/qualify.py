"""Qualify discovered boundaries, reducing load after an unsuccessful trial."""

import copy
import json
from pathlib import Path

from guidance import PROFILES, SIZES, build_sizing, usable
from matrix import validate_matrix
from settings import ROOT, require, save, sha256
from stopping import CaseRunner, parameters_for, passed


def specification(report):
    report = Path(report)
    manifest = json.loads((report / 'manifest.json').read_text())
    results = json.loads((report / 'results.json').read_text())
    matrix = json.loads((report / 'replay.json').read_text())
    validate_matrix(matrix)
    require(manifest['status'] == 'measured', 'Finish discovery before qualifying its boundaries.')
    require(manifest.get('candidateRestorationRequired') is False, 'Verify discovery restoration before qualification.')
    require(manifest['nativeTls'] is True and manifest['pipelining'] is False, 'Qualification requires native TLS without pipelining.')
    expected_settings = {
        'databasePoolLimit': 100, 'mergeConcurrencyLimit': 50, 'commitHints': False,
        'persistentSessionLogging': False, 'consoleSessionLogging': False,
    }
    require(all(manifest.get(key) == value for key, value in expected_settings.items()),
            'Discovery must use the same pool, merge limit, hints, and logging configuration.')

    clients = manifest['clientBuilds']
    require(len(clients) == 1, 'Qualification requires one benchmark client build.')
    client = clients[0]['sha256']
    cases = {case['id']: case for case in matrix['cases']}
    sizing = build_sizing(results, manifest)
    trials = [
        (result, parameters_for(cases[result['label']]['size'], cases[result['label']]['parameters']['schema'], cases[result['label']]['parameters']))
        for result in results if result['label'] in cases and result.get('clientSha256') == client
    ]
    plan = {
        'format': 1,
        'serverExecutableSha256': manifest['serverExecutableSha256'],
        'clientSha256': client,
        'dependencies': manifest['dependencies'],
        'databasePlacement': manifest['databasePlacement'],
        'sourceFiles': {name: sha256(report / name) for name in ('manifest.json', 'results.json', 'replay.json')},
        'sizes': [],
    }

    for size in SIZES:
        active = []
        for schema, workload, _ in PROFILES:
            screen = next(row for row in sizing['activeScreens'] if row['rows'] == 1 and row['schema'] == schema and row['workload'] == workload)
            chosen = screen['sizes'][size]['keptUp']
            representative = chosen['representative']
            entry = {'schema': schema, 'workload': workload, 'startingUsers': None}
            if representative is not None:
                matching = [
                    (trial, parameters) for trial, parameters in trials
                    if trial['instanceSize'] == size and parameters['schema'] == schema
                    and parameters['workload'] == workload and parameters['rows'] == 1
                    and parameters['mode'] == 'continuous' and parameters['write_mode'] == 'insert'
                    and parameters['schedule'] == 'spread' and parameters['period'] == 2000
                    and parameters['payload_bytes'] == 128 and parameters['devices'] == 2
                    and parameters['users'] == parameters['active_users'] > 0
                    and (parameters['rounds'] == 8 or parameters['rounds'] >= 150)
                ]
                failures = [(trial, parameters) for trial, parameters in matching
                            if not usable(trial) or trial.get('keptUp') is not True]
                users = chosen['users']
                while users and any(parameters['active_users'] <= users for _, parameters in failures):
                    users //= 2

                qualified = [
                    trial['label'] for trial, parameters in matching
                    if parameters['rounds'] >= 150 and parameters['active_users'] == users
                    and usable(trial) and trial.get('keptUp') is True
                ]
                entry.update({
                    'startingUsers': users or None,
                    'sourceScreen': representative['label'],
                    'parameters': copy.deepcopy(cases[representative['label']]['parameters']),
                    'priorFailures': [trial['label'] for trial, _ in failures],
                    'alreadyQualified': qualified,
                })
            active.append(entry)

        idle_trials = [
            (trial, parameters) for trial, parameters in trials
            if trial['instanceSize'] == size and parameters['schema'] == 'full'
            and parameters['active_users'] == 0
        ]
        idle_passes = [(trial, parameters) for trial, parameters in idle_trials
                       if usable(trial) and trial.get('exerciseCompleted')]
        idle_failures = [trial for trial in idle_trials if trial not in idle_passes]
        failed = min(idle_failures, key=lambda trial: trial[1]['users'] * trial[1]['devices'], default=None)
        upper = failed[1]['users'] * failed[1]['devices'] if failed else None
        lower = max((parameters['users'] * parameters['devices'] for _, parameters in idle_passes
                     if upper is None or parameters['users'] * parameters['devices'] < upper), default=0)
        idle = {
            'passingConnectedDevices': lower,
            'failingTargetDevices': upper,
            'sourceTrials': [trial['label'] for trial, _ in idle_trials],
            'parameters': copy.deepcopy(failed[1]) if failed else None,
        }
        plan['sizes'].append({'size': size, 'active': active, 'idle': idle})

    return plan


def validate_build(plan, config):
    require(plan['serverExecutableSha256'] == config['serverExecutableSha256'], 'Qualification must use the discovery server executable.')
    require(plan['clientSha256'] == config['clientSha256'], 'Qualification must use the discovery client executable.')
    require(plan['dependencies'] == config['dependencies'], 'Qualification dependencies differ from discovery.')
    require(plan['databasePlacement'] == config['databasePlacement'], 'Qualification database placement differs from discovery.')


def qualify(plan, *, case_runner=None, root=ROOT):
    runner = case_runner or CaseRunner(root)
    outcomes = {'format': 1, 'sourceFiles': plan['sourceFiles'], 'sizes': []}

    for tier in plan['sizes']:
        size = tier['size']
        outcome = {'size': size, 'idle': copy.deepcopy(tier['idle']), 'active': []}
        outcomes['sizes'].append(outcome)
        idle = outcome['idle']
        idle['followupCases'] = []
        lower, upper = idle['passingConnectedDevices'], idle['failingTargetDevices']
        while upper is not None:
            users = upper // 4
            connected = users * 2
            if users < 1 or connected <= lower:
                break

            parameters = {**idle['parameters'], 'users': users, 'active_users': 0}
            label = f'{size}-full-idle-c{connected}-qualification'
            result = runner.run({'id': label, 'size': size, 'parameters': parameters})
            idle['followupCases'].append(label)
            if passed(parameters, result) and result.get('exerciseCompleted'):
                lower = connected
                break
            upper = connected

        idle.update({'passingConnectedDevices': lower, 'failingTargetDevices': upper})
        idle['scope'] = 'Failed setup is not a measured established-stream ceiling. No heavier target is attempted after failure.'
        save(root / 'qualification.json', outcomes)

        for entry in tier['active']:
            selected = {
                'schema': entry['schema'], 'workload': entry['workload'],
                'sourceScreen': entry.get('sourceScreen'), 'priorFailures': entry.get('priorFailures', []),
                'qualifiedUsers': None, 'followupCases': [], 'reusedCases': [],
            }
            outcome['active'].append(selected)
            users = entry['startingUsers']
            if users and entry.get('alreadyQualified'):
                selected.update({'qualifiedUsers': users, 'reusedCases': entry['alreadyQualified']})
                users = None

            while users:
                parameters = {**entry['parameters'], 'users': users, 'active_users': users, 'rounds': 150}
                label = f"{size}-{entry['schema']}-{entry['workload']}-r1-c{users * 2}-a{users * 2}-qualification-t2"
                result = runner.run({'id': label, 'size': size, 'parameters': parameters})
                selected['followupCases'].append(label)
                if passed(parameters, result):
                    selected['qualifiedUsers'] = users
                    break
                users //= 2

            selected['status'] = 'qualified' if selected['qualifiedUsers'] is not None else 'unqualified'
            save(root / 'qualification.json', outcomes)

    return outcomes
