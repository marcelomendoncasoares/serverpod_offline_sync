"""Guard against turning failed or differently scheduled runs into capacity."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from guidance import active_screens, boundary, build_sizing, render


def trial(label, devices, *, correct=True, observed=True, p95=500, client='current'):
    return {
        'label': label,
        'instanceSize': 'medium',
        'schema': 'full',
        'clientSha256': client,
        'correct': correct,
        'observationsComplete': observed,
        'keptUp': True,
        'options': {
            'mode': 'continuous', 'write-mode': 'insert', 'schedule': 'spread',
            'period-ms': 2000, 'rounds': 8, 'payload-bytes': 128,
            'devices-min': 2, 'devices-max': 2,
            'schema': 'full', 'workload': 'person', 'rows': 1,
        },
        'load': {
            'participatingDevices': devices, 'connectedDevices': devices,
            'activeUsers': devices // 2,
        },
        'latency': {'p95Ms': p95},
    }


class SizingEvidenceTest(unittest.TestCase):
    def test_failed_repetition_does_not_disappear_behind_a_pass(self):
        results = [trial('lower', 8), trial('higher-pass', 32), trial('higher-fail', 32, correct=False)]

        value = boundary(results, subsecond=False)

        self.assertEqual(value['devices'], 8)
        self.assertIn('higher-fail', value['allTrials'])

    def test_incomplete_observations_and_old_client_are_not_qualifying_screens(self):
        results = [trial('lower', 8), trial('missing', 16, observed=False), trial('old', 32, client='old')]

        value = build_sizing(results, {'clientBuilds': [{'sha256': 'current'}]})

        cell = next(r for r in value['activeScreens'] if r['workload'] == 'person' and r['rows'] == 1)
        self.assertEqual(cell['sizes']['medium']['keptUp']['devices'], 8)
        self.assertEqual(cell['sizes']['medium']['keptUp']['allTrials'], ['lower', 'missing'])

    def test_slower_offered_rate_is_not_an_improvement_at_the_original_rate(self):
        normal = trial('normal', 8)
        relaxed = trial('ten-seconds', 64)
        relaxed['options']['period-ms'] = 10000
        relaxed['options']['rounds'] = 4

        selected = active_screens([normal, relaxed], 'current')

        self.assertEqual([r['label'] for r in selected], ['normal'])

    def test_throughput_and_latency_targets_remain_distinct(self):
        results = [trial('lower', 8), trial('higher', 32, p95=1200)]

        throughput = boundary(results, subsecond=False)
        latency = boundary(results, subsecond=True)

        self.assertEqual(throughput['devices'], 32)
        self.assertEqual(latency['devices'], 8)
        self.assertEqual(throughput['offeredRoundsPerSecond'], 8)

    def test_representative_keeps_the_worst_p95_repetition(self):
        results = [trial('first', 8, p95=400), trial('repeat', 8, p95=700)]

        value = boundary(results, subsecond=True)

        self.assertEqual(value['representative']['label'], 'repeat')
        self.assertEqual(value['selectedTrials'], ['first', 'repeat'])

    def test_idle_capacity_is_independent_of_the_active_device_screen(self):
        active = trial('active', 8)
        idle = copy.deepcopy(active)
        idle.update(label='idle', exerciseCompleted=True)
        idle['load'].update(activeUsers=0, connectedDevices=256, participatingDevices=0)
        interrupted = copy.deepcopy(idle)
        interrupted.update(label='interrupted', correct=False, exerciseCompleted=False)
        interrupted['load']['connectedDevices'] = 1024

        value = build_sizing([active, idle, interrupted], {'clientBuilds': [{'sha256': 'current'}]})

        cell = next(r for r in value['idleConnections'] if r['size'] == 'medium')
        self.assertEqual(cell['largestSuccessfulTrial']['load']['connectedDevices'], 256)
        self.assertEqual([r['label'] for r in cell['unsuccessfulTrials']], ['interrupted'])

    def test_sustained_linked_and_isolated_schema_results_are_visible(self):
        for schema, workload in [('full', 'town-linked'), ('city', 'city')]:
            with self.subTest(schema=schema, workload=workload), tempfile.TemporaryDirectory() as temporary:
                result = trial('sustained', 16)
                result['options'].update(schema=schema, workload=workload, rounds=150)
                result['latency'].update(count=1200, minMs=100, medianMs=200, meanMs=250, maxMs=900)
                report = Path(temporary)
                (report / 'results.json').write_text(json.dumps([result]))
                (report / 'manifest.json').write_text(json.dumps({'clientBuilds': [{'sha256': 'current'}]}))

                render(report)

                document = (report / 'SIZING.md').read_text()
                self.assertIn(f'medium / {schema}/{workload} / 5-minute offered workload', document)
                self.assertIn('| 16 / 16 | 1200 |', document)


if __name__ == '__main__':
    unittest.main()
