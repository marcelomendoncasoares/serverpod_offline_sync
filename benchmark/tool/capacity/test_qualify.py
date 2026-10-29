"""Check sustained qualification and downward refinements without Cloud calls."""

import json
import tempfile
import unittest
from pathlib import Path

from matrix import digest
from qualify import qualify, specification, validate_build
from settings import SIZES


def write_report(directory, examples, *, status='measured'):
    directory.mkdir(parents=True, exist_ok=True)
    cases = []
    results = []
    for example in examples:
        label = example['label']
        size = example.get('size', 'medium')
        schema = example.get('schema', 'full')
        workload = example.get('workload', 'person')
        users = example['users']
        active = 0 if example.get('idle') else users
        rounds = example.get('rounds', 8)
        correct = example.get('correct', True)
        parameters = {
            'schema': schema, 'workload': workload, 'users': users, 'active_users': active,
            'devices': 2, 'rows': 1, 'rounds': rounds, 'period': 2000,
            'mode': 'continuous', 'write_mode': 'insert', 'schedule': 'spread', 'payload_bytes': 128,
        }
        cases.append({
            'id': label, 'size': size, 'parameters': parameters,
            'caseSha256': digest({'size': size, 'parameters': parameters}),
        })
        results.append({
            'label': label, 'instanceSize': size, 'schema': schema, 'clientSha256': 'client',
            'correct': correct, 'observationsComplete': example.get('observed', True),
            'keptUp': example.get('kept_up', correct), 'exerciseCompleted': correct,
            'options': None if example.get('missing_summary') else {
                'schema': schema, 'workload': workload, 'rows': 1, 'rounds': rounds,
                'mode': 'continuous', 'write-mode': 'insert', 'schedule': 'spread',
                'period-ms': 2000, 'payload-bytes': 128, 'devices-min': 2, 'devices-max': 2,
            },
            'load': None if example.get('missing_summary') else {
                'activeUsers': active, 'connectedDevices': users * 2, 'participatingDevices': active * 2,
            },
            'latency': {'p95Ms': 500},
        })

    manifest = {
        'status': status, 'candidateRestorationRequired': False,
        'nativeTls': True, 'pipelining': False, 'serverExecutableSha256': 'server',
        'clientBuilds': [{'sha256': 'client'}], 'dependencies': {}, 'databasePlacement': 'same region',
        'databasePoolLimit': 100, 'mergeConcurrencyLimit': 50, 'commitHints': False,
        'persistentSessionLogging': False, 'consoleSessionLogging': False,
    }
    for name, value in [
        ('manifest.json', manifest), ('results.json', results),
        ('replay.json', {'format': 1, 'cases': cases, 'matrixSha256': digest(cases)}),
    ]:
        (directory / name).write_text(json.dumps(value))


class MeasurementRecorder:
    def __init__(self, *, largest_successful_users):
        self.largest_successful_users = largest_successful_users
        self.cases = []

    def run(self, case):
        self.cases.append(case)
        success = case['parameters']['users'] <= self.largest_successful_users
        return {'correct': success, 'observationsComplete': True,
                'keptUp': success, 'exerciseCompleted': success}


class QualificationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.report = self.root / 'discovery'

    def test_given_a_failed_sustained_point_when_qualified_then_load_halves_until_it_keeps_up(self):
        write_report(self.report, [{'label': 'medium-screen', 'users': 16}])
        plan = specification(self.report)
        measurements = MeasurementRecorder(largest_successful_users=4)

        result = qualify(plan, case_runner=measurements, root=self.root)

        self.assertEqual([case['parameters']['users'] for case in measurements.cases], [16, 8, 4])
        self.assertTrue(all(case['parameters']['rounds'] == 150 for case in measurements.cases))
        self.assertTrue(all(case['parameters']['period'] == 2000 for case in measurements.cases))
        self.assertEqual(result['sizes'][1]['active'][0]['qualifiedUsers'], 4)

    def test_given_an_earlier_long_failure_without_a_summary_when_planned_then_heavier_load_is_avoided(self):
        write_report(self.report, [
            {'label': 'medium-screen', 'users': 32},
            {'label': 'medium-long-failure', 'users': 8, 'rounds': 150, 'correct': False, 'missing_summary': True},
        ])

        plan = specification(self.report)

        person = plan['sizes'][1]['active'][0]
        self.assertEqual(person['startingUsers'], 4)
        self.assertEqual(person['priorFailures'], ['medium-long-failure'])

    def test_given_an_existing_successful_long_trial_when_qualified_then_it_is_reused(self):
        write_report(self.report, [
            {'label': 'medium-screen', 'users': 4},
            {'label': 'medium-long-pass', 'users': 4, 'rounds': 150},
        ])
        measurements = MeasurementRecorder(largest_successful_users=4)

        result = qualify(specification(self.report), case_runner=measurements, root=self.root)

        self.assertEqual(measurements.cases, [])
        self.assertEqual(result['sizes'][1]['active'][0]['reusedCases'], ['medium-long-pass'])
        self.assertEqual(result['sizes'][1]['active'][0]['qualifiedUsers'], 4)

    def test_given_failed_idle_setup_without_a_summary_when_qualified_then_only_smaller_targets_are_attempted(self):
        write_report(self.report, [
            {'label': 'idle-256-pass', 'users': 128, 'idle': True},
            {'label': 'idle-4096-fail', 'users': 2048, 'idle': True, 'correct': False, 'missing_summary': True},
        ])
        measurements = MeasurementRecorder(largest_successful_users=512)

        result = qualify(specification(self.report), case_runner=measurements, root=self.root)

        self.assertEqual([case['parameters']['users'] * 2 for case in measurements.cases], [2048, 1024])
        self.assertTrue(all(case['parameters']['active_users'] == 0 for case in measurements.cases))
        self.assertEqual(result['sizes'][1]['idle']['passingConnectedDevices'], 1024)
        self.assertEqual(result['sizes'][1]['idle']['failingTargetDevices'], 2048)

    def test_given_no_successful_refinement_when_qualified_then_no_sustained_capacity_is_claimed(self):
        write_report(self.report, [{'label': 'medium-screen', 'users': 4}])
        measurements = MeasurementRecorder(largest_successful_users=0)

        result = qualify(specification(self.report), case_runner=measurements, root=self.root)

        self.assertEqual([case['parameters']['users'] for case in measurements.cases], [4, 2, 1])
        self.assertEqual(result['sizes'][1]['active'][0]['status'], 'unqualified')
        self.assertIsNone(result['sizes'][1]['active'][0]['qualifiedUsers'])

    def test_given_screens_on_all_five_tiers_when_qualified_then_every_tier_is_measured(self):
        write_report(self.report, [
            {'label': 'small-screen', 'size': 'small', 'users': 1},
            {'label': 'medium-screen', 'size': 'medium', 'users': 1},
            {'label': 'large-screen', 'size': 'large', 'users': 1},
            {'label': 'xlarge-screen', 'size': 'xlarge', 'users': 1},
            {'label': 'xxlarge-screen', 'size': 'xxlarge', 'users': 1},
        ])
        measurements = MeasurementRecorder(largest_successful_users=1)

        result = qualify(specification(self.report), case_runner=measurements, root=self.root)

        self.assertEqual([case['size'] for case in measurements.cases], SIZES)
        self.assertEqual([tier['active'][0]['status'] for tier in result['sizes']], ['qualified'] * 5)

    def test_given_unfinished_discovery_when_planned_then_qualification_is_rejected(self):
        write_report(self.report, [], status='measuring')

        with self.assertRaisesRegex(ValueError, 'Finish discovery'):
            specification(self.report)

    def test_given_three_schema_profiles_when_qualified_then_each_profile_gets_its_own_long_trial(self):
        write_report(self.report, [
            {'label': 'person-screen', 'users': 4},
            {'label': 'town-screen', 'users': 4, 'workload': 'town-linked'},
            {'label': 'city-screen', 'users': 4, 'schema': 'city', 'workload': 'city'},
        ])
        measurements = MeasurementRecorder(largest_successful_users=4)

        qualify(specification(self.report), case_runner=measurements, root=self.root)

        self.assertEqual(
            [(case['parameters']['schema'], case['parameters']['workload']) for case in measurements.cases],
            [('full', 'person'), ('full', 'town-linked'), ('city', 'city')],
        )
        self.assertTrue(all(case['parameters']['rounds'] == 150 for case in measurements.cases))

    def test_given_an_incompletely_observed_long_pass_when_planned_then_it_cannot_qualify_the_load(self):
        write_report(self.report, [
            {'label': 'medium-screen', 'users': 4},
            {'label': 'medium-incomplete-long', 'users': 4, 'rounds': 150, 'observed': False},
        ])

        plan = specification(self.report)

        person = plan['sizes'][1]['active'][0]
        self.assertEqual(person['startingUsers'], 2)
        self.assertEqual(person['alreadyQualified'], [])
        self.assertEqual(person['priorFailures'], ['medium-incomplete-long'])

    def test_given_a_different_server_build_when_validated_then_discovery_cannot_be_reused(self):
        write_report(self.report, [])
        plan = specification(self.report)
        config = {**plan, 'serverExecutableSha256': 'different-server'}

        with self.assertRaisesRegex(ValueError, 'discovery server executable'):
            validate_build(plan, config)


if __name__ == '__main__':
    unittest.main()
