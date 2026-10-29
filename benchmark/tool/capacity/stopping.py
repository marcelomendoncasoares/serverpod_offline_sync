"""Stop heavier comparable loads after an unsuccessful measurement."""

import json

from settings import ROOT, save


POLICY = 'stop-heavier-comparable-loads-v1'
LOAD_AXES = {'users', 'active_users', 'rows', 'rounds'}


def parameters_for(size, schema, parameters):
    return {
        'schema': schema, 'users': 4, 'active_users': 4,
        'devices': 2, 'workers': 8,
        'warmup_workers': 1 if size == 'small' else 4,
        'rows': 1, 'rounds': 10, 'period': 2000,
        'idle_seconds': 45, 'settle_seconds': 5, 'payload_bytes': 128,
        'timeout': 30, 'sample': 30, 'startup': 1200, 'deadline': 3600,
        'workload': 'person', 'schedule': 'spread', 'setup': 1,
        'write_mode': 'insert', 'mode': 'continuous', 'profile': True,
        **{key.replace('-', '_'): value for key, value in parameters.items()},
    }


def passed(parameters, result):
    return bool(
        result.get('correct') and result.get('observationsComplete')
        and (parameters['active_users'] == 0 or result.get('keptUp'))
    )


class CaseRunner:
    def __init__(self, root=ROOT):
        self.root = root
        self.current = None
        self.failed = []
        self.skipped = []
        save(self.root / 'skipped-cases.json', self.skipped)

    def transition_to(self, size, schema):
        from transition import transition

        destination = (size, schema)
        if destination != self.current:
            transition(*destination)
            self.current = destination

    def run(self, case):
        from campaign import run_case

        parameters = parameters_for(case['size'], case['parameters']['schema'], case['parameters'])
        for earlier, previous, result in self.failed:
            if earlier['size'] != case['size']:
                continue
            if (parameters['active_users'] == 0) != (previous['active_users'] == 0):
                continue

            fixed = (parameters.keys() | previous.keys()) - LOAD_AXES - {'quota'}
            if any(parameters.get(key) != previous.get(key) for key in fixed):
                continue
            if not all(parameters[key] >= previous[key] for key in LOAD_AXES):
                continue

            skipped = {
                'id': case['id'], 'size': case['size'], 'parameters': parameters,
                'status': 'skipped', 'blockedBy': earlier['id'],
                'reason': 'An equal or lighter comparable load did not pass correctness, observations, and offered rate.',
                'blockingVerdict': {key: result.get(key) for key in ['correct', 'observationsComplete', 'keptUp']},
            }
            self.skipped.append(skipped)
            save(self.root / 'skipped-cases.json', self.skipped)
            print(json.dumps(skipped), flush=True)
            return skipped

        self.transition_to(case['size'], parameters['schema'])
        result = run_case(case['id'], **parameters)
        if not passed(parameters, result):
            self.failed.append((case, parameters, result))
        return result
