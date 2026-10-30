"""Protect capacity conclusions when combining discovery and follow-up reports."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import capacity_merge


def observation(label, *, correct=True):
    return {
        'label': label, 'runId': 'run-' + label, 'instanceSize': 'medium',
        'serverExecutableSha256': 'server', 'clientSha256': 'client',
        'correct': correct, 'observationsComplete': True, 'keptUp': correct,
        'schema': 'full',
        'options': {
            'mode': 'continuous', 'write-mode': 'insert', 'schedule': 'spread',
            'period-ms': 2000, 'payload-bytes': 128, 'devices-min': 2,
            'devices-max': 2, 'rounds': 150, 'rows': 1,
            'schema': 'full', 'workload': 'person',
        },
        'load': {'activeUsers': 4, 'participatingDevices': 8, 'connectedDevices': 8},
        'latency': {'count': 600, 'minMs': 100, 'medianMs': 200,
                    'meanMs': 220, 'p95Ms': 300, 'maxMs': 400},
    }


class MergeTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / 'combined'

    def report(self, name, results, **changes):
        path = self.root / name
        path.mkdir()
        manifest = {key: 'same' for key in capacity_merge.MATCHING_CONFIGURATION}
        manifest.update({
            'status': 'measured', 'serverExecutableSha256': 'server',
            'clientBuilds': [{'sha256': 'client', 'sourceRevision': 'revision'}],
            'restorationRequired': True, **changes,
        })
        capacity_merge.save(path / 'manifest.json', manifest)
        capacity_merge.save(path / 'results.json', results)
        (path / 'rounds.jsonl').write_text('{}\n')
        return path

    def test_failed_repetition_remains_disqualifying_and_raw_sources_are_retained(self):
        first = self.report('discovery', [observation('passing')])
        second = self.report('followups', [observation('failed', correct=False)])
        (first / 'RESOURCE_ACCOUNTING.md').write_text('Unresolved counters.\n')
        capacity_merge.save(second / 'skipped-cases.json', [{'id': 'heavier', 'blockedBy': 'failed'}])

        result = capacity_merge.merge([first, second], self.output)

        self.assertEqual(result['uniqueRuns'], 2)
        sizing = capacity_merge.read(self.output / 'sizing.json')
        medium = next(row for row in sizing['sustainedOneRow']
                      if row['size'] == 'medium' and row['workload'] == 'person')
        self.assertIsNone(medium['keptUp']['devices'])
        self.assertEqual(set(medium['keptUp']['allTrials']), {'passing', 'failed'})
        self.assertFalse((self.output / 'rounds.jsonl').exists())
        sources = capacity_merge.read(self.output / 'sources.json')
        self.assertEqual(sources[0]['files']['rounds.jsonl'], capacity_merge.digest(first / 'rounds.jsonl'))
        self.assertIn('CPU accounting', (self.output / 'SIZING.md').read_text())
        self.assertEqual(capacity_merge.read(self.output / 'skipped-cases.json')[0]['sourceReport'], 'followups')

    def test_different_runtime_or_configuration_is_rejected_before_writing(self):
        first = self.report('first', [observation('one')])
        for key in ['serverExecutableSha256', 'databasePoolLimit', 'databasePlacement', 'dependencies']:
            with self.subTest(key=key):
                other = self.report(key, [observation('two')], **{key: 'changed'})
                with self.assertRaisesRegex(ValueError, 'Incompatible configuration: ' + key):
                    capacity_merge.merge([first, other], self.output)
                self.assertFalse(self.output.exists())

    def test_identical_copy_is_counted_once_but_conflicting_label_is_rejected(self):
        first = self.report('first', [observation('same')])
        other = self.report('copy', [observation('same')])
        self.assertEqual(capacity_merge.merge([first, other], self.output)['uniqueRuns'], 1)
        changed = observation('same', correct=False)
        capacity_merge.save(other / 'results.json', [changed])

        with self.assertRaisesRegex(ValueError, 'Conflicting observations'):
            capacity_merge.merge([first, other], self.output)

    def test_ambiguous_client_requires_selection_and_unlisted_result_client_is_rejected(self):
        first = self.report('first', [observation('one')])
        second_result = copy.deepcopy(observation('two'))
        second_result['clientSha256'] = 'other-client'
        other = self.report('second', [second_result], clientBuilds=[{'sha256': 'other-client'}])

        with self.assertRaisesRegex(ValueError, 'Select --client-sha256'):
            capacity_merge.merge([first, other], self.output)
        capacity_merge.merge([first, other], self.output, 'client')
        self.assertEqual(capacity_merge.read(self.output / 'sizing.json')['screenClientSha256'], 'client')

        second_result['clientSha256'] = 'unknown'
        capacity_merge.save(other / 'results.json', [second_result])
        with self.assertRaisesRegex(ValueError, 'Result client differs'):
            capacity_merge.merge([first, other], self.output, 'client')

    def test_unfinished_source_is_rejected_and_inputs_cannot_be_overwritten(self):
        first = self.report('unfinished', [observation('one')], status='measuring')
        with self.assertRaisesRegex(ValueError, 'completed individual reports'):
            capacity_merge.merge([first], self.output)
        with self.assertRaisesRegex(ValueError, 'distinct sibling directories'):
            capacity_merge.merge([first], first)

    def test_cli_combines_reports_with_default_and_explicit_client_selection(self):
        first = self.report('discovery', [observation('one')])
        second = self.report('qualification', [observation('two')])

        for client_sha in [None, 'client']:
            with self.subTest(client_sha=client_sha):
                output = self.root / ('combined-' + (client_sha or 'default'))
                command = [
                    sys.executable, str(Path(capacity_merge.__file__)),
                    '--reports', str(first), str(second),
                    '--output', str(output),
                ]
                if client_sha is not None:
                    command.extend(['--client-sha256', client_sha])

                process = subprocess.run(
                    command, capture_output=True, text=True, timeout=30,
                )

                self.assertEqual(process.returncode, 0, process.stderr)
                self.assertEqual(json.loads(process.stdout), {
                    'reports': 2, 'uniqueRuns': 2, 'selectedClient': 'client',
                })
                self.assertEqual(
                    {row['label'] for row in capacity_merge.read(output / 'results.json')},
                    {'one', 'two'},
                )
                self.assertTrue((output / 'SIZING.md').exists())


if __name__ == '__main__':
    unittest.main()
