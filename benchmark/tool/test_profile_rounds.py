"""Behavioral checks for duration-only client/server correlation."""

import unittest

from profile_rounds import split_client_residual


def measured_round():
    return {
        'round': 4,
        'writer': 0,
        'peers': 1,
        'localCommitMicros': 10,
        'writeToAllPeersMicros': 150,
        'peerAppliedMicros': [{'device': 1, 'micros': 150}],
        'clientProfile': {
            'round': 4,
            'writer': 0,
            'droppedBatches': 0,
            'batches': [
                {'device': 0, 'direction': 'sent', 'batchId': 7,
                 'firstChunkMicros': 15, 'endMicros': 20},
                {'device': 1, 'direction': 'received', 'batchId': 3,
                 'firstChunkMicros': 110, 'endMicros': 120},
            ],
        },
    }


class ClientCorrelationTest(unittest.TestCase):
    def test_matching_round_conserves_total_without_cross_machine_timestamps(self):
        measured = measured_round()

        parts = split_client_residual(measured, 7, 3, server_path=40)

        self.assertEqual(parts, {
            'clientLocalWrite': 10,
            'clientOutboundPreparation': 10,
            'transportAndBoundaryResidual': 60,
            'clientPeerApplyAndObserve': 30,
        })
        self.assertEqual(sum(parts.values()) + 40, measured['writeToAllPeersMicros'])

    def test_wrong_numbered_server_batch_is_rejected(self):
        with self.assertRaises(AssertionError):
            split_client_residual(measured_round(), 8, 3, server_path=40)

    def test_missing_boundary_is_rejected_instead_of_guessed(self):
        measured = measured_round()
        del measured['clientProfile']['batches'][1]['endMicros']

        with self.assertRaises(KeyError):
            split_client_residual(measured, 7, 3, server_path=40)

    def test_wrong_writer_identity_is_rejected(self):
        measured = measured_round()
        measured['clientProfile']['writer'] = 1

        with self.assertRaises(AssertionError):
            split_client_residual(measured, 7, 3, server_path=40)

    def test_negative_transport_residual_remains_visible_for_partition_rejection(self):
        parts = split_client_residual(measured_round(), 7, 3, server_path=101)

        self.assertEqual(parts['transportAndBoundaryResidual'], -1)


if __name__ == '__main__':
    unittest.main()
