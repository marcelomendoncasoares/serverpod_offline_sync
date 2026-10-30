"""Export resource boundaries without publishing private runtime identities."""

import argparse
import datetime
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def profile(config_path):
    config = read(Path(config_path))
    evidence = Path(config['evidenceDirectory'])
    state = read(evidence / 'campaign.json')
    rows = []

    for label in state['cases']:
        receipt = read(evidence / 'cases' / (label + '.json'))
        boundaries = receipt.get('summary', {}).get('boundaries', {})
        instances = {sample['server']['instanceId'] for sample in boundaries.values()}
        selected = {}

        for phase, sample in boundaries.items():
            process = sample['process']
            selected[phase] = {
                'time': sample['time'],
                'echoStreams': sample['transport']['open'],
                'offlineSyncStreams': sample['streams']['open'],
                'openFileDescriptors': process.get('openFds'),
                'cgroupMemoryBytes': sample['memoryCgroup'].get('currentBytes'),
                'residentMemoryBytes': process.get('rssBytes'),
                'cpuUserTicks': process.get('cpuUserTicks'),
                'cpuSystemTicks': process.get('cpuSystemTicks'),
            }

        idle = None
        if len(instances) == 1 and 'open' in selected and 'idle' in selected:
            start = selected['open']
            end = selected['idle']
            elapsed = (datetime.datetime.fromisoformat(end['time']) -
                       datetime.datetime.fromisoformat(start['time'])).total_seconds()
            ticks = sum(end[key] - start[key] for key in ['cpuUserTicks', 'cpuSystemTicks'])
            idle = {
                'intervalIncludingSettleSeconds': elapsed,
                'cpuTicksPerSecond': 100,
                'cpuCoresAverage': ticks / 100 / elapsed,
                'cgroupMemoryIncreaseBytes': end['cgroupMemoryBytes'] - start['cgroupMemoryBytes'],
            }

        rows.append({
            'case': label,
            'passed': receipt['passed'],
            'instanceChangedBetweenBoundaries': len(instances) > 1,
            'boundaries': selected,
            'idleInterval': idle,
        })

    report = Path(config['reportDirectory'])
    (report / 'resource-boundaries.json').write_text(json.dumps(rows, indent=2) + '\n')
    return {'resourceProfilesExported': len(rows)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    print(json.dumps(profile(parser.parse_args().config)))
