"""Adaptive load brackets; failed and slow observations are never discarded."""

import argparse
import fcntl
import json

from campaign import ROOT, read
from stopping import CaseRunner


def sustained(workload, row_points, active_users=None, maximum_rows=40000, *, case_runner=None):
    state = read(ROOT / 'campaign-state.json')
    size = state['currentSize']
    schema = state['currentSchema']
    tag = '-' + state['clientCampaignTag'] if state.get('clientCampaignTag') else ''
    brackets = []
    runner = case_runner or CaseRunner(ROOT)

    points = sorted(set(row_points))
    user_points = sorted(set(active_users or [1, 4, 16, 64, 256]))
    for rows in points:
        observations = {}
        skipped = {}

        def measure(users):
            label = f'{size}-{schema}-{workload}-r{rows}-c{users * 2}-a{users * 2}-spread{tag}'
            result = runner.run({
                'id': label, 'size': size,
                'parameters': {'schema': schema, 'users': users, 'active_users': users,
                               'workload': workload, 'rows': rows, 'rounds': 8, 'timeout': 45},
            })
            if result.get('status') == 'skipped':
                skipped[users] = result
                return False

            observations[users] = result
            return result['correct'] and result['observationsComplete'] and result['keptUp']

        last_pass = 0
        first_fail = None
        for users in user_points:
            if measure(users):
                last_pass = users
            elif first_fail is None:
                first_fail = users

        if first_fail and last_pass and first_fail > last_pass * 2:
            middle = first_fail // 2
            if measure(middle):
                last_pass = middle
            else:
                first_fail = middle

        bracket = {
            'size': size, 'schema': schema, 'workload': workload, 'rows': rows,
            'periodMs': 2000, 'passingActiveUsers': last_pass,
            'failingActiveUsers': first_fail if first_fail in observations else None,
            'labels': [r['label'] for r in observations.values()],
            'skippedActiveUsers': sorted(skipped),
            'blockedBy': sorted({result['blockedBy'] for result in skipped.values()}),
            'interpretation': 'Finite eight-round screen. Skipped loads are unmeasured, not observed failures. Sustain passing points before sizing guidance.',
        }
        brackets.append(bracket)
        (ROOT / f'{size}-{schema}-{workload}-brackets{tag}.json').write_text(json.dumps(brackets, indent=2) + '\n')
        print(json.dumps({'bracket': bracket}), flush=True)
        if rows == points[-1] and rows >= 1000 and rows < maximum_rows and last_pass:
            points.append(min(maximum_rows, 5000 if rows == 1000 else rows * 2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('workload', choices=['person', 'town-linked', 'town', 'city'])
    parser.add_argument('--rows', type=int, nargs='+', default=[1, 10, 50, 200, 1000])
    args = parser.parse_args()
    with (ROOT / 'campaign.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        sustained(args.workload, args.rows)
