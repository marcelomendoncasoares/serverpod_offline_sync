"""Guard against turning failed or differently scheduled runs into capacity."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from guidance import active_screens, boundary, build_sizing, render, sustained_controls


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

    def test_short_pass_does_not_override_a_sustained_failure(self):
        short = trial('short-pass', 32)
        lower = trial('sustained-lower', 8)
        lower['options']['rounds'] = 150
        higher = trial('sustained-failed', 32)
        higher['options']['rounds'] = 150
        higher['keptUp'] = False

        value = build_sizing([short, lower, higher], {'clientBuilds': [{'sha256': 'current'}]})

        screen = next(r for r in value['activeScreens'] if r['workload'] == 'person' and r['rows'] == 1)
        sustained = next(r for r in value['sustainedOneRow'] if r['size'] == 'medium' and r['workload'] == 'person')
        self.assertEqual(screen['sizes']['medium']['keptUp']['devices'], 32)
        self.assertEqual(sustained['keptUp']['devices'], 8)
        self.assertEqual(sustained['keptUp']['allTrials'], ['sustained-lower', 'sustained-failed'])

    def test_sustained_point_keeps_failed_repetitions_and_latency_target(self):
        lower = trial('lower', 8)
        higher = trial('higher', 32, p95=1200)
        repeated = trial('higher-incomplete', 32, observed=False)
        for result in [lower, higher, repeated]:
            result['options']['rounds'] = 150
        manifest = {'clientBuilds': [{'sha256': 'current'}]}

        first = build_sizing([lower, higher], manifest)
        repeated_result = build_sizing([lower, higher, repeated], manifest)

        select = lambda value: next(r for r in value['sustainedOneRow'] if r['size'] == 'medium' and r['workload'] == 'person')
        self.assertEqual(select(first)['keptUp']['devices'], 32)
        self.assertEqual(select(first)['p95BelowOneSecond']['devices'], 8)
        self.assertEqual(select(repeated_result)['keptUp']['devices'], 8)

    def test_mixed_short_or_differently_scheduled_runs_do_not_validate_sustained_capacity(self):
        results = [trial(name, 8) for name in ['valid', 'mixed', 'short', 'slow', 'old', 'larger-batch']]
        for result in results:
            result['options']['rounds'] = 150
        results[1]['load']['connectedDevices'] = 256
        results[2]['options']['rounds'] = 149
        results[3]['options']['period-ms'] = 10000
        results[4]['clientSha256'] = 'old'
        results[5]['options']['rows'] = 10

        selected = sustained_controls(results, 'current')

        self.assertEqual([r['label'] for r in selected], ['valid'])


if __name__ == '__main__':
    unittest.main()
