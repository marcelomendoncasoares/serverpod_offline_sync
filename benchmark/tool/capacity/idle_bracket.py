import argparse
import fcntl
import json

from campaign import ROOT, read, run_case


def bracket(points, warmup_workers):
    state = read(ROOT / 'campaign-state.json')
    size, schema = state['currentSize'], state['currentSchema']
    tag = '-' + state['clientCampaignTag'] if state.get('clientCampaignTag') else ''
    workload = 'city' if schema == 'city' else 'person'
    passing = 0
    failing = None
    labels = []
    for connected in points:
        label = f'{size}-{schema}-idle-c{connected}-w{warmup_workers}{tag}'
        result = run_case(
            label, users=connected // 2, active_users=0, rounds=1,
            workload=workload, workers=8, warmup_workers=warmup_workers,
            startup=1800, deadline=5400,
        )
        labels.append(label)
        if result['correct'] and result['observationsComplete']:
            passing = connected
        else:
            failing = connected
            break

    value = {
        'size': size, 'schema': schema, 'passingConnectedDevices': passing,
        'failingTargetDevices': failing, 'labels': labels,
        'scope': 'A failed startup is not a measured established-stream ceiling; consult each run phase and generator evidence.',
    }
    (ROOT / f'{size}-{schema}-idle-bracket.json').write_text(json.dumps(value, indent=2) + '\n')
    print(json.dumps(value), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--points', type=int, nargs='+', default=[64, 256, 1024, 4096, 8192])
    parser.add_argument('--warmup-workers', type=int, default=4)
    args = parser.parse_args()
    with (ROOT / 'campaign.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        bracket(args.points, args.warmup_workers)
