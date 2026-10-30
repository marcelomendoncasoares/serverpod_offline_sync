import argparse
import tempfile
import unittest
from pathlib import Path

from idle_capacity import Campaign, save


class IdleCapacityTests(unittest.TestCase):
    def campaign(self, outcomes):
        campaign = Campaign.__new__(Campaign)
        campaign.args = argparse.Namespace(
            sizes=['small', 'medium', 'large', 'xlarge', 'xxlarge'],
            points=[64, 256, 1024], qualification_idle_seconds=300,
        )
        campaign.state = {'tiers': []}
        campaign.persist = lambda: None
        campaign.export = lambda: None
        campaign.visited = []
        campaign.calls = []
        campaign.transition = campaign.visited.append

        def run(size, count, idle, suffix):
            campaign.calls.append((size, count, idle, suffix))
            return {'passed': outcomes(count, idle)}

        campaign.run_case = run
        return campaign

    def test_every_tier_runs_but_heavier_counts_stop_after_failure(self):
        campaign = self.campaign(lambda count, idle: count <= 64)

        campaign.measure()

        self.assertEqual(campaign.visited, ['small', 'medium', 'large', 'xlarge', 'xxlarge'])
        self.assertFalse(any(count == 1024 for _, count, _, _ in campaign.calls))
        self.assertEqual([t['longIdleQualified'] for t in campaign.state['tiers']], [64] * 5)

    def test_a_long_idle_failure_requires_a_smaller_qualification(self):
        campaign = self.campaign(lambda count, idle: idle == 45 or count <= 128)
        campaign.args.sizes = ['medium']
        campaign.args.points = [64, 256]

        campaign.measure()

        self.assertEqual(campaign.calls[-2:], [
            ('medium', 256, 300, 'qualification'), ('medium', 128, 300, 'qualification'),
        ])
        self.assertEqual(campaign.state['tiers'][0]['largestShortPass'], 256)
        self.assertEqual(campaign.state['tiers'][0]['longIdleQualified'], 128)

    def test_an_incomplete_receipt_is_not_silently_rerun(self):
        with tempfile.TemporaryDirectory() as path:
            campaign = Campaign.__new__(Campaign)
            campaign.root = Path(path)
            campaign.config = {'clientSha256': 'client'}
            campaign.state = {'serverExecutableSha256': 'server'}
            save(campaign.root / 'cases/small-echo-c64-idle45-screen.json', {
                'status': 'running',
                'workload': {'size': 'small', 'connections': 64, 'idleSeconds': 45,
                    'openWorkers': 1, 'workers': 8, 'clientSha256': 'client',
                    'serverExecutableSha256': 'server'},
            })

            with self.assertRaisesRegex(ValueError, 'incomplete case'):
                campaign.run_case('small', 64, 45, 'screen')


if __name__ == '__main__':
    unittest.main()
