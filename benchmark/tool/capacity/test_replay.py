"""Offline regression checks for reproducible evidence and comparisons."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from compare import compare
from matrix import digest, freeze, validate_matrix


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


def receipt(directory, label, *, exit_code=0):
    value = {
        'command': ['rounds', '--target', 'https://private.invalid/',
                    '--users', '4', '--devices', '2', '--workers', '4',
                    '--active-users', '4', '--rows', '10', '--rounds', '8',
                    '--period-ms', '2000', '--schema', 'full',
                    '--workload', 'person', '--payload-bytes', '128',
                    '--settle-seconds', '5', '--write-mode', 'insert',
                    '--mode', 'continuous', '--schedule', 'spread'],
        'clientSha256': 'client-one', 'instanceSize': 'small',
        'sampleUserIndices': [0], 'parameters': {'deadline': 3600},
    }
    if exit_code is not None:
        value['exitCode'] = exit_code
    write_json(directory / (label + '.json'), value)


def report(directory, *, correct=True, kept_up=True, mean=100, quota=.1):
    case = {'id': 'small-reference', 'size': 'small',
            'parameters': {'users': 4, 'schema': 'full'}}
    case['caseSha256'] = digest({'size': case['size'], 'parameters': case['parameters']})
    write_json(directory / 'replay.json', {'format': 1, 'cases': [case], 'matrixSha256': digest([case])})
    write_json(directory / 'manifest.json', {'serverExecutableSha256': 'server', 'databasePlacement': 'same region'})
    write_json(directory / 'results.json', [{
        'label': case['id'], 'correct': correct, 'keptUp': kept_up,
        'observationsComplete': True, 'cpuQuota': quota, 'memoryLimitBytes': 256,
        'latency': {'meanMs': mean, 'medianMs': mean, 'p95Ms': mean},
    }])


class FrozenMatrixTest(unittest.TestCase):
    def test_given_failed_and_passed_cases_when_frozen_then_both_are_retained(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            write_json(directory / 'campaign-state.json', {
                'runs': ['small-pass', 'small-fail', 'small-running'],
                'nativeExecutableSha256': 'baseline-server',
            })
            receipt(directory, 'small-pass')
            receipt(directory, 'small-fail', exit_code=1)
            receipt(directory, 'small-running', exit_code=None)

            value = freeze(directory, directory / 'replay.json')

            self.assertEqual([case['id'] for case in value['cases']], ['small-pass', 'small-fail'])
            self.assertNotIn('private.invalid', json.dumps(value))
            self.assertEqual(value['cases'][0]['parameters']['payload_bytes'], 128)
            self.assertEqual(value['cases'][0]['parameters']['period'], 2000)

    def test_given_changed_workload_when_validated_then_fingerprint_mismatch_is_rejected(self):
        case = {'id': 'small-reference', 'size': 'small', 'parameters': {'rows': 1}}
        case['caseSha256'] = digest({'size': case['size'], 'parameters': case['parameters']})
        value = {'format': 1, 'cases': [case], 'matrixSha256': digest([case])}
        case['parameters']['rows'] = 50

        with self.assertRaisesRegex(ValueError, 'matrix changed'):
            validate_matrix(value)

    def test_given_local_receipts_when_cli_freezes_then_no_cloud_configuration_is_needed(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            write_json(directory / 'campaign-state.json', {'runs': ['small-pass'], 'nativeExecutableSha256': 'server'})
            receipt(directory, 'small-pass')

            result = subprocess.run([
                sys.executable, str(Path(__file__).with_name('run.py')),
                '--evidence', temporary, 'freeze', '--matrix', str(directory / 'matrix.json'),
            ], capture_output=True, text=True, check=True)

            self.assertEqual(json.loads(result.stdout)['cases'], 1)
            self.assertEqual(json.loads((directory / 'matrix.json').read_text())['cases'][0]['parameters']['rows'], 10)


class ComparisonTest(unittest.TestCase):
    def test_given_matched_passes_when_compared_then_latency_reduction_is_reported(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report(directory / 'before', mean=100)
            report(directory / 'after', mean=50)

            result = compare(directory / 'before', directory / 'after', directory / 'comparison')

            self.assertEqual(result['cases'][0]['reductionsPercent'], {'medianMs': 50, 'meanMs': 50, 'p95Ms': 50})

    def test_given_failed_baseline_when_candidate_passes_then_partial_latency_is_not_a_speedup(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report(directory / 'before', correct=False, mean=100)
            report(directory / 'after', mean=50)

            result = compare(directory / 'before', directory / 'after', directory / 'comparison')

            self.assertIsNone(result['cases'][0]['reductionsPercent'])
            self.assertFalse(result['cases'][0]['baselineCorrect'])
            self.assertTrue(result['cases'][0]['candidateCorrect'])

    def test_given_different_cpu_budget_when_compared_then_no_matched_speedup_is_claimed(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report(directory / 'before', quota=.1)
            report(directory / 'after', quota=2)

            result = compare(directory / 'before', directory / 'after', directory / 'comparison')

            self.assertFalse(result['cases'][0]['matchingResources'])
            self.assertIsNone(result['cases'][0]['reductionsPercent'])

    def test_given_convergence_without_rate_adherence_when_compared_then_kept_up_stays_separate(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            report(directory / 'before', kept_up=False)
            report(directory / 'after', kept_up=True)

            result = compare(directory / 'before', directory / 'after', directory / 'comparison')

            self.assertTrue(result['cases'][0]['baselineCorrect'])
            self.assertFalse(result['cases'][0]['baselineKeptUp'])
            self.assertTrue(result['cases'][0]['candidateKeptUp'])


if __name__ == '__main__':
    unittest.main()
