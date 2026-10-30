"""Cold-instance WebSocket compression controls using the same echo endpoint."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import tempfile

from idle_capacity import Campaign, require, save, utc


def main():
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Interrupted by signal {signum}.')

    signal.signal(signal.SIGTERM, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    args.sizes = ['small']
    args.points = [256, 2048]
    args.qualification_idle_seconds = 300
    campaign = Campaign(args)
    admissions = campaign.config.get('admissionControls', [])
    args.sizes = list(dict.fromkeys([item['size'] for item in admissions] + ['small']))
    args.points = sorted({256, 2048, *(item['connections'] for item in admissions)})
    directory = Path(tempfile.gettempdir()) / f'offline-sync-capacity-locks-{os.getuid()}'
    directory.mkdir(mode=0o700, exist_ok=True)
    name = hashlib.sha256(json.dumps(campaign.config['project'], sort_keys=True,
                                    separators=(',', ':')).encode()).hexdigest()
    controls = []
    with (directory / name).open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            campaign.deploy()
            admission_results = []
            for admission_index, spec in enumerate(admissions):
                campaign.transition(spec['size'])
                before = campaign.wait_ready()
                if admission_index and admissions[admission_index - 1]['size'] == spec['size']:
                    campaign.cli(['deploy', '--redeploy', '--no-await'])
                    before = campaign.wait_ready(changed_instance=before['server']['instanceId'])
                os.environ['BENCHMARK_WEBSOCKET_COMPRESSION'] = 'enabled'
                result = campaign.run_case(spec['size'], spec['connections'], 300,
                                           'admission-slower')
                events_path = campaign.root / 'runs' / result['label'] / 'events.jsonl'
                events = [json.loads(line) for line in events_path.read_text().splitlines()]
                opened = [event for event in events if event['type'] == 'opened']
                require(bool(opened), 'No admission handshake was completed.')
                require(all('permessage-deflate' in event.get('negotiatedExtensions', '')
                            and event.get('upgradeHttpStatus') == 101 for event in opened),
                        'Admission control did not retain ordinary compression.')
                statuses = sorted({event['upgradeHttpStatus'] for event in events
                                   if event.get('upgradeHttpStatus') not in [None, 101]})
                admission_results.append({
                    'label': result['label'], 'size': spec['size'],
                    'connections': spec['connections'], 'idleSeconds': 300,
                    'openingConcurrency': result['workload']['openWorkers'] *
                        result['workload']['openConcurrencyPerWorker'],
                    'passed': result['passed'], 'checkedHandshakes': len(opened),
                    'nonUpgradeHttpStatuses': statuses,
                    'compression': 'permessage-deflate',
                    'coldInstance': before['server']['instanceId'],
                    'recordedAt': utc(),
                })
                save(campaign.root / 'admission-controls.json', admission_results)
                save(Path(campaign.config['reportDirectory']) / 'admission-controls.json',
                     [{key: value for key, value in item.items() if key != 'coldInstance'}
                      for item in admission_results])
                print(json.dumps({'admissionControl': result['label'],
                                  'passed': result['passed'],
                                  'nonUpgradeHttpStatuses': statuses}), flush=True)

            campaign.transition('small')
            for index, (mode, count, idle) in enumerate([
                ('enabled', 256, 45), ('disabled', 256, 45), ('disabled', 2048, 300),
            ]):
                if index == 2 and not controls[-1]['passed']:
                    break
                before = campaign.wait_ready()
                if index or (admissions and admissions[-1]['size'] == 'small'):
                    campaign.cli(['deploy', '--redeploy', '--no-await'])
                    before = campaign.wait_ready(changed_instance=before['server']['instanceId'])
                os.environ['BENCHMARK_WEBSOCKET_COMPRESSION'] = mode
                result = campaign.run_case('small', count, idle, 'compression-' + mode)
                summary = result.get('summary', {})
                require(summary.get('options', {}).get('transport-compression') == mode,
                        'The selected compression mode did not reach the client.')
                events_path = campaign.root / 'runs' / result['label'] / 'events.jsonl'
                events = [json.loads(line) for line in events_path.read_text().splitlines()]
                opened = [e for e in events if e['type'] == 'opened']
                require(bool(opened), 'No completed handshake to verify compression negotiation.')
                require(all(e.get('compressionMode') == mode for e in opened), 'Mixed compression modes.')
                extensions = sorted({e.get('negotiatedExtensions') for e in opened})
                require(all(('permessage-deflate' in value) == (mode == 'enabled')
                            for value in extensions), 'Unexpected negotiated WebSocket extensions.')
                control = {'label': result['label'], 'mode': mode, 'connections': count,
                    'idleSeconds': idle, 'passed': result['passed'],
                    'negotiatedExtensions': extensions, 'checkedHandshakes': len(opened),
                    'coldInstance': before['server']['instanceId'],
                    'recordedAt': utc()}
                controls.append(control)
                save(campaign.root / 'compression-controls.json', controls)
                save(Path(campaign.config['reportDirectory']) / 'compression-controls.json',
                     [{k: v for k, v in item.items() if k != 'coldInstance'} for item in controls])
                print(json.dumps({'compressionControl': control['label'], 'passed': control['passed'],
                                  'negotiatedExtensions': extensions}), flush=True)
            require(len({c['coldInstance'] for c in controls}) == len(controls),
                    'The controls did not run on separate fresh instances.')
            campaign.state['status'] = 'measured'
            campaign.persist()
        finally:
            os.environ.pop('BENCHMARK_WEBSOCKET_COMPRESSION', None)
            if campaign.state.get('restorationRequired'):
                campaign.restore()
            campaign.export()


if __name__ == '__main__':
    main()
