"""Exercise adaptive stopping without contacting Cloud."""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run
import sweep
from matrix import digest
from settings import SIZES
from stopping import CaseRunner


def case(label, *, size='large', schema='full', **parameters):
    value = {'id': label, 'size': size, 'parameters': {'schema': schema, **parameters}}
    value['caseSha256'] = digest({'size': size, 'parameters': value['parameters']})
    return value


def outcome(label, *, correct=True, observed=True, kept_up=True):
    return {'label': label, 'correct': correct, 'observationsComplete': observed, 'keptUp': kept_up}


class StoppingTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))
        self.transition = self.enterContext(patch('transition.transition'))
        self.measure = self.enterContext(patch('campaign.run_case'))

    def test_given_failed_200_rows_when_sweeping_then_1000_rows_and_slower_retries_are_not_run(self):
        (self.root / 'campaign-state.json').write_text(json.dumps({
            'currentSize': 'xxlarge', 'currentSchema': 'full',
        }))
        self.measure.side_effect = lambda label, **p: outcome(label, kept_up=p['rows'] < 200)

        with patch.object(sweep, 'ROOT', self.root):
            sweep.sustained('person', [1, 200, 1000], [1, 4, 16])

        measured = [(call.kwargs['rows'], call.kwargs['users']) for call in self.measure.call_args_list]
        self.assertEqual(measured, [(1, 1), (1, 4), (1, 16), (200, 1)])
        self.assertTrue(all(call.kwargs['period'] == 2000 for call in self.measure.call_args_list))
        skipped = json.loads((self.root / 'skipped-cases.json').read_text())
        self.assertEqual(len(skipped), 5)
        brackets = json.loads((self.root / 'xxlarge-full-person-brackets.json').read_text())
        self.assertIsNone(brackets[-1]['failingActiveUsers'])
        self.assertEqual(brackets[-1]['labels'], [])

    def test_given_concurrency_failure_when_rows_increase_then_lower_concurrency_is_still_measured(self):
        (self.root / 'campaign-state.json').write_text(json.dumps({
            'currentSize': 'large', 'currentSchema': 'full',
        }))
        self.measure.side_effect = lambda label, **p: outcome(label, kept_up=p['users'] < 16)

        with patch.object(sweep, 'ROOT', self.root):
            sweep.sustained('person', [1, 10], [1, 4, 16])

        measured = [(call.kwargs['rows'], call.kwargs['users']) for call in self.measure.call_args_list]
        self.assertIn((1, 8), measured)
        self.assertIn((10, 8), measured)
        self.assertNotIn((10, 16), measured)

    def test_given_idle_failure_when_replaying_then_heavier_connections_are_skipped_and_next_tier_runs(self):
        cases = [
            case('large-256', users=128, active_users=0),
            case('large-1024', users=512, active_users=0),
            case('xlarge-1024', size='xlarge', users=512, active_users=0),
        ]
        self.measure.side_effect = lambda label, **p: outcome(label, correct=label != 'large-256', kept_up=None)

        with patch('stopping.ROOT', self.root), patch('stopping.CaseRunner', lambda: CaseRunner(self.root)):
            run.replay({'format': 1, 'cases': cases, 'matrixSha256': digest(cases)})

        self.assertEqual([call.args[0] for call in self.measure.call_args_list], ['large-256', 'xlarge-1024'])
        self.assertEqual(self.transition.call_count, 2)
        skipped = json.loads((self.root / 'skipped-cases.json').read_text())
        self.assertEqual(skipped[0]['blockedBy'], 'large-256')

    def test_given_incomplete_observations_when_load_increases_then_no_capacity_failure_is_invented(self):
        runner = CaseRunner(self.root)
        self.measure.return_value = outcome('incomplete', observed=False)

        runner.run(case('incomplete', rows=200))
        result = runner.run(case('heavier', rows=1000))

        self.assertEqual(self.measure.call_count, 1)
        self.assertEqual(result['status'], 'skipped')
        self.assertTrue(result['blockingVerdict']['correct'])
        self.assertFalse(result['blockingVerdict']['observationsComplete'])
        self.assertNotIn('latency', result)

    def test_given_failure_when_workload_changes_then_independent_paths_are_not_pruned(self):
        runner = CaseRunner(self.root)
        self.measure.side_effect = lambda label, **p: outcome(label, kept_up=label != 'failed')
        independent = [
            case('different-tier', size='xxlarge'),
            case('different-schema', schema='city'),
            case('different-workload', workload='town-linked'),
            case('different-schedule', schedule='burst'),
            case('different-period', period=10000),
            case('different-mode', mode='once'),
            case('idle', active_users=0),
        ]

        runner.run(case('failed'))
        for item in independent:
            runner.run(item)

        self.assertEqual(self.measure.call_count, 1 + len(independent))

    def test_given_a_new_campaign_when_old_load_failed_then_the_new_version_can_be_measured(self):
        self.measure.side_effect = [outcome('failed', kept_up=False), outcome('changed-build')]
        before = CaseRunner(self.root)
        before.run(case('failed', rows=200))
        before.run(case('skipped', rows=1000))

        after = CaseRunner(self.root)
        result = after.run(case('changed-build', rows=1000))

        self.assertTrue(result['keptUp'])
        self.assertEqual(self.measure.call_count, 2)
        self.assertEqual(json.loads((self.root / 'skipped-cases.json').read_text()), [])

    def test_given_default_plan_when_discovering_then_all_five_tiers_are_automatic_even_after_failures(self):
        plan = json.loads(Path(__file__).with_name('plans').joinpath('standard.json').read_text())
        self.measure.side_effect = lambda label, **p: outcome(label, kept_up=False)

        with patch('stopping.CaseRunner', lambda: CaseRunner(self.root)), \
                patch('idle_bracket.bracket') as idle, patch('sweep.sustained') as active:
            run.discover(plan, None)

        references = [call.args[0] for call in self.measure.call_args_list if call.args[0].endswith('-full-reference')]
        self.assertEqual(references, [size + '-full-reference' for size in SIZES])
        self.assertEqual(idle.call_count, 5)
        self.assertEqual(active.call_count, 15)


if __name__ == '__main__':
    unittest.main()
