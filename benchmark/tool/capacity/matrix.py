"""Freeze actual case arguments, including failed cases, for matched replays."""

import hashlib
import json
import re
from pathlib import Path

from settings import SIZES, require, save


# Translate the public rounds CLI into the campaign wrapper's arguments.
ARGUMENTS = {
    'users': 'users', 'devices': 'devices', 'workers': 'workers',
    'active-users': 'active_users', 'schedule': 'schedule',
    'warmup-workers': 'warmup_workers', 'idle-seconds': 'idle_seconds',
    'settle-seconds': 'settle_seconds',
    'payload-bytes': 'payload_bytes',
    'rounds': 'rounds', 'rows': 'rows', 'period-ms': 'period',
    'sample-seconds': 'sample', 'timeout-seconds': 'timeout',
    'startup-timeout-seconds': 'startup', 'setup-concurrency': 'setup',
    'schema': 'schema', 'workload': 'workload', 'write-mode': 'write_mode',
    'mode': 'mode', 'client-profile-user': 'client_profile_user',
}
STRINGS = {'schedule', 'schema', 'workload', 'write_mode', 'mode'}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def freeze(evidence, destination, client_sha256=None):
    evidence = Path(evidence)
    state = json.loads((evidence / 'campaign-state.json').read_text())
    cases = []
    for label in state['runs']:
        receipt = json.loads((evidence / (label + '.json')).read_text())
        if 'exitCode' not in receipt or client_sha256 and receipt['clientSha256'] != client_sha256:
            continue

        command = receipt['command'][1:]
        parameters = {}
        for index, argument in enumerate(command):
            if not argument.startswith('--'):
                continue
            key = ARGUMENTS.get(argument[2:])
            if key:
                value = command[index + 1]
                parameters[key] = value if key in STRINGS else int(value)

        # These two values were fixed by the collector, outside the rounds CLI.
        parameters['deadline'] = receipt.get('parameters', {}).get('deadline', 5400 if parameters.get('active_users') == 0 else 3600)
        parameters['profile'] = bool(receipt.get('sampleUserIndices'))
        if 'payload_bytes' not in parameters:
            summary = json.loads((Path(receipt['output']) / 'summary.json').read_text())
            parameters['payload_bytes'] = summary['options']['payload-bytes']
        size = receipt.get('instanceSize', label.split('-')[0])
        require(size in SIZES, 'The receipt does not identify a supported instance size: ' + label)
        require(parameters.get('schema') in ['full', 'city'], 'The receipt does not identify its schema: ' + label)
        case = {'id': label, 'size': size, 'parameters': parameters}
        case['caseSha256'] = digest({'size': size, 'parameters': parameters})
        cases.append(case)

    require(bool(cases), 'No completed receipts matched the requested client build.')
    value = {
        'format': 1,
        'description': 'Exact completed cases, including failed cases; no adaptive stopping during replay.',
        'baselineServerSha256': state['nativeExecutableSha256'],
        'baselineClientSha256': client_sha256,
        'cases': cases,
    }
    value['matrixSha256'] = digest(cases)
    save(destination, value)
    return value


def validate_matrix(value):
    require(value['format'] == 1, 'Unsupported matrix format.')
    require(value['matrixSha256'] == digest(value['cases']), 'The matrix changed without updating its fingerprint.')
    ids = set()
    for case in value['cases']:
        require(re.fullmatch(r'[a-z0-9][a-z0-9_.-]*', case['id']), 'Case IDs must be safe filenames.')
        require(case['id'] not in ids, 'Duplicate case ID: ' + case['id'])
        require(case['size'] in SIZES, 'Unsupported instance size.')
        require(case['caseSha256'] == digest({'size': case['size'], 'parameters': case['parameters']}), 'Case parameters differ from their fingerprint.')
        ids.add(case['id'])

