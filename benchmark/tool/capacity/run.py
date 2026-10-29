#!/usr/bin/env python3
"""Discover capacity, freeze the measured matrix, and replay it after a change."""

import argparse
import contextlib
import fcntl
import json
import os
import sys
import tempfile
from pathlib import Path


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--config', help='Private JSON settings; required for Cloud actions.')
    result.add_argument('--evidence', help='Override the evidence directory for offline actions.')
    commands = result.add_subparsers(dest='action', required=True)

    discover = commands.add_parser('discover', help='Find boundaries using the versioned discovery plan.')
    discover.add_argument('--plan', default=str(Path(__file__).with_name('plans') / 'standard.json'))
    discover.add_argument('--sizes', nargs='+', choices=['small', 'medium', 'large', 'xlarge', 'xxlarge'])
    discover.add_argument('--leave-deployed', action='store_true', help='Continue this campaign later without restoring its starting settings yet.')

    replay = commands.add_parser('replay', help='Run every frozen case, retaining failures.')
    replay.add_argument('--matrix', required=True)
    replay.add_argument('--baseline', help='A previous report directory for a matched comparison.')
    replay.add_argument('--leave-deployed', action='store_true')

    freeze = commands.add_parser('freeze', help='Record actual completed case arguments without Cloud calls.')
    freeze.add_argument('--matrix', required=True)
    freeze.add_argument('--client-sha256', help='Restrict the matrix to a single benchmark client version.')

    compare = commands.add_parser('compare', help='Compare two exported reports without Cloud calls.')
    compare.add_argument('--baseline', required=True)
    compare.add_argument('--candidate', required=True)
    compare.add_argument('--output', required=True)

    commands.add_parser('export', help='Regenerate the report and replay matrix from raw receipts.')
    commands.add_parser('restore', help='Retry and verify restoration from the saved snapshot.')
    commands.add_parser('status', help='Read the local progress ledger without Cloud calls.')
    return result


def initialize():
    from deployment import snapshot
    from settings import CONFIG, ROOT, require, save, validate_configuration

    validate_configuration()
    state_path = ROOT / 'campaign-state.json'
    if state_path.exists():
        state = json.loads(state_path.read_text())
        require(state['nativeExecutableSha256'] == CONFIG['serverExecutableSha256'], 'Use a fresh evidence directory for a different server build.')
        require(state['clientBuilds'][-1]['sha256'] == CONFIG['clientSha256'], 'Use a fresh evidence directory for a different client build.')
        require((ROOT / 'restoration-snapshot.json').is_file(), 'The restoration snapshot is missing.')
        return state

    original = snapshot()
    state = {
        'status': 'measuring', 'runs': [], 'nativeTls': True, 'pipelining': False,
        'sourceRevision': CONFIG['sourceRevision'],
        'baseRevision': CONFIG.get('baseRevision'), 'branch': CONFIG.get('branch'),
        'nativeExecutableSha256': CONFIG['serverExecutableSha256'],
        'clientBuilds': [{'sha256': CONFIG['clientSha256'], 'sourceRevision': CONFIG['clientSourceRevision']}],
        'currentSize': original['compute']['size'],
        'currentSchema': original['metrics']['server']['benchmarkSchema'],
        'currentQuota': original['metrics']['cpuCgroup']['quotaCores'],
        'restorationRequired': True,
        'dartVersion': CONFIG['dartVersion'],
        'databasePlacement': CONFIG['databasePlacement'],
    }
    save(state_path, state)
    save(ROOT / 'deployment-manifest.json', {'dependencies': CONFIG['dependencies']})
    return state


def replay(value):
    from campaign import run_case
    from matrix import validate_matrix
    from transition import transition

    validate_matrix(value)
    current = None
    for case in value['cases']:
        destination = (case['size'], case['parameters']['schema'])
        if destination != current:
            transition(*destination)
            current = destination
        run_case(case['id'], **case['parameters'])


def discover(plan, sizes):
    from campaign import run_case
    from idle_bracket import bracket
    from settings import SIZES, require
    from sweep import sustained
    from transition import transition

    require(plan['format'] == 1, 'Unsupported discovery plan format.')
    for size in sizes or plan['sizes']:
        require(size in SIZES, 'Unsupported instance size.')
        transition(size, 'full')
        run_case(f'{size}-full-reference', **plan['reference'])
        bracket(plan['idleConnectedDevices'], 1 if size == 'small' else 4)
        for profile in plan['profiles']:
            transition(size, profile['schema'])
            sustained(profile['workload'], plan['rows'], plan['activeUsers'], plan['maximumRows'])
        for control in plan['controls']:
            transition(size, control['schema'])
            run_case(f'{size}-{control["id"]}', **control['parameters'])


def export_all():
    from export_evidence import DESTINATION, export
    from matrix import freeze
    from settings import ROOT

    export()
    state = json.loads((ROOT / 'campaign-state.json').read_text())
    if state['runs']:
        freeze(ROOT, DESTINATION / 'replay.json')


def main():
    args = parser().parse_args()
    if args.config:
        os.environ['CAPACITY_CONFIG'] = str(Path(args.config).expanduser().resolve())
    if args.evidence:
        os.environ['CAPACITY_EVIDENCE'] = str(Path(args.evidence).expanduser().resolve())

    from settings import ROOT, require, save

    if args.action == 'compare':
        from compare import compare
        compare(args.baseline, args.candidate, args.output)
        return
    if args.action == 'freeze':
        from matrix import freeze
        value = freeze(ROOT, args.matrix, args.client_sha256)
        print(json.dumps({'cases': len(value['cases']), 'matrixSha256': value['matrixSha256']}))
        return
    if args.action == 'status':
        state = json.loads((ROOT / 'campaign-state.json').read_text())
        print(json.dumps({key: state.get(key) for key in ['status', 'currentSize', 'currentSchema', 'runs', 'restorationRequired']}, indent=2))
        return

    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    with contextlib.ExitStack() as stack:
        lock = stack.enter_context((ROOT / 'campaign.lock').open('w'))
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'export':
            export_all()
            return
        from matrix import digest
        from settings import CONFIG
        lock_directory = Path(tempfile.gettempdir()) / f'offline-sync-capacity-locks-{os.getuid()}'
        lock_directory.mkdir(mode=0o700, exist_ok=True)
        project_lock = stack.enter_context((lock_directory / digest(CONFIG['project'])).open('w'))
        fcntl.flock(project_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

        if args.action == 'restore':
            from deployment import restore
            restore()
            export_all()
            return

        state = initialize()
        specification = json.loads(Path(args.matrix if args.action == 'replay' else args.plan).read_text())
        invocation = {'action': args.action, 'specification': specification, 'sizes': getattr(args, 'sizes', None)}
        fingerprint = digest(invocation)
        require(state.get('planSha256', fingerprint) == fingerprint, 'Resume requires the same workload plan. Use a fresh evidence directory for a new plan.')
        state.update({'planSha256': fingerprint, 'status': 'measuring', 'restorationRequired': True})
        save(ROOT / 'campaign-state.json', state)
        save(ROOT / 'invocation.json', invocation)
        try:
            if args.action == 'replay':
                replay(specification)
            else:
                discover(specification, args.sizes)
            state = json.loads((ROOT / 'campaign-state.json').read_text())
            state['status'] = 'measured'
            save(ROOT / 'campaign-state.json', state)
        except BaseException:
            state = json.loads((ROOT / 'campaign-state.json').read_text())
            state['status'] = 'interrupted'
            save(ROOT / 'campaign-state.json', state)
            raise
        finally:
            try:
                if not args.leave_deployed:
                    from deployment import restore
                    restore()
            finally:
                export_all()

        if args.action == 'replay' and args.baseline:
            from compare import compare
            from export_evidence import DESTINATION
            compare(args.baseline, DESTINATION, DESTINATION / 'comparison')


if __name__ == '__main__':
    main()

