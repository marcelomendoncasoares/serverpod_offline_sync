"""Adaptive load brackets; failed and slow observations are never discarded."""

import argparse
import fcntl
import json
from pathlib import Path

from campaign import ROOT, read, run_case


def sustained(workload, row_points, active_users=None, maximum_rows=40000):
    state = read(ROOT / 'campaign-state.json')
    size = state['currentSize']
    schema = state['currentSchema']
    tag = '-' + state['clientCampaignTag'] if state.get('clientCampaignTag') else ''
    brackets = []

    points = list(row_points)
    for rows in points:
        observations = {}

        def measure(users):
            label = f'{size}-{schema}-{workload}-r{rows}-c{users * 2}-a{users * 2}-spread{tag}'
            result = run_case(
                label, users=users, active_users=users, workload=workload,
                rows=rows, rounds=8, timeout=45,
            )
            observations[users] = result
            return result['correct'] and result['observationsComplete'] and result['keptUp']

        last_pass = 0
        first_fail = None
        for users in active_users or [1, 4, 16, 64, 256]:
            if measure(users):
                last_pass = users
            else:
                first_fail = users
                break

        if first_fail and last_pass and first_fail > last_pass * 2:
            middle = first_fail // 2
            if measure(middle):
                last_pass = middle
            else:
                first_fail = middle

        if not last_pass:
            run_case(
                f'{size}-{schema}-{workload}-r{rows}-c2-a2-period10s{tag}',
                users=1, active_users=1, workload=workload, rows=rows,
                rounds=4, period=10000, timeout=90,
            )

        bracket = {
            'size': size, 'schema': schema, 'workload': workload, 'rows': rows,
            'periodMs': 2000, 'passingActiveUsers': last_pass,
            'failingActiveUsers': first_fail,
            'labels': [r['label'] for r in observations.values()],
            'interpretation': 'Finite eight-round screen. Repeat and sustain useful points before sizing guidance.',
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
