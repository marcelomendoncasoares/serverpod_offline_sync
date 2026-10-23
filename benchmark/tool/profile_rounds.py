"""Pair sampled server frames with benchmark rounds on one monotonic timeline.

Usage: python3 benchmark/tool/profile_rounds.py EVIDENCE_DIRECTORY LABEL
The runner receipt points to the immutable client and server event files.
"""

import collections
import json
import math
import statistics
import sys
from pathlib import Path


def distribution(values):
    values = sorted(values)
    return {
        'n': len(values),
        'minMs': values[0] / 1000,
        'meanMs': statistics.mean(values) / 1000,
        'medianMs': statistics.median(values) / 1000,
        'p95Ms': values[math.ceil(len(values) * .95) - 1] / 1000,
        'maxMs': values[-1] / 1000,
    }


def records(path):
    return [json.loads(line) for line in Path(path).read_text().splitlines()]


def analyze(root, label):
    receipt = json.loads((root / (label + '.json')).read_text())
    collector = receipt['collector']
    assert collector['stopped'] and not collector['gaps'], collector
    collected = records(receipt['serverEvents'])
    sequences = [e['sequence'] for e in collected]
    assert sequences == list(range(sequences[0], collector['cursor'] + 1)), 'Incomplete collector sequence'
    server = [e for e in collected if e.get('runId') == receipt['runId']]
    client = records(Path(receipt['output']) / 'events.jsonl')
    rounds = {(e['user'], e['round']): e for e in client if e['type'] == 'round' and e['phase'] == 'exercise'}
    traces = {e['requestId']: e for e in server if e['type'] == 'syncTrace'}
    assert len(traces) == 2 * len(receipt['sampleUserIds'])
    assert all(not e['unfinishedSpans'] and not e['droppedDetails'] for e in traces.values())
    frames = [e for e in server if e['type'] == 'syncFrame']
    merges = {(e['requestId'], e['batchId']): e for e in server if e['type'] == 'mergeTrace'}
    transactions = [e for e in server if e['type'] == 'syncTransaction']
    captures = collections.defaultdict(list)
    starts = {}
    for record in server:
        if record['type'] != 'syncTimeline':
            continue
        event = record['event']
        key = (record['requestId'], event['spanId'])
        if event['kind'] == 'start':
            starts[key] = event
        if event['kind'] == 'end':
            start = starts.pop(key)
            if event['name'] == 'sync.outboundCapture':
                captures[record['requestId']].append((start, event))
    assert not starts, 'Unfinished spans'

    rows = []
    for user, user_id in zip(receipt['sampleUserIndices'], receipt['sampleUserIds']):
        for (index, sequence), measured in sorted(rounds.items()):
            if index != user:
                continue
            identity = {'round': sequence, 'writer': measured['writer']}
            matching = [f for f in frames if f['userId'] == user_id and identity in f.get('rounds', [])]
            incoming = [f for f in matching if f['direction'] == 'received']
            outgoing = [f for f in matching if f['direction'] == 'yielded']
            incoming_keys = {(f['requestId'], f['batchId']) for f in incoming}
            outgoing_keys = {(f['requestId'], f['batchId']) for f in outgoing}
            assert len(incoming_keys) == len(outgoing_keys) == 1, (user, sequence, incoming_keys, outgoing_keys)
            source = incoming_keys.pop()
            peer = outgoing_keys.pop()
            assert source[0] != peer[0]
            merge = merges[source]
            ends = [f for f in frames if (f['requestId'], f['batchId']) == peer and f['direction'] == 'yielded' and f['frame'] == 'end']
            assert len(ends) == 1
            sent = ends[0]['processMicros']
            begin = merge['processOriginMicros'] + merge['startMicros']
            end = merge['processOriginMicros'] + merge['endMicros']
            capture = max((c for c in captures[peer[0]] if c[1]['processMicros'] <= sent), key=lambda c: c[1]['processMicros'])
            cap_start, cap_end = capture[0]['processMicros'], capture[1]['processMicros']
            cap_transactions = [t for t in transactions if t['requestId'] == peer[0] and t['parentId'] == capture[0]['spanId']]
            assert len(cap_transactions) == len(merge['transactions']) == 1
            tx = merge['transactions'][0]
            cap_tx = cap_transactions[0]
            queue = sum(v for k, v in merge['timings'].items() if k.startswith('queue.'))
            preparation = merge['timings'].get('merge.prepareSources', 0)
            parts = {
                'mergeQueue': queue,
                'mergeSourcePreparation': preparation,
                'mergeConnectionAndBegin': tx['connectionWaitAndBeginMicros'],
                'mergeSql': tx['sqlWallMicros'],
                'mergeNonSql': tx['unattributedBodyMicros'],
                'mergeCommitAndRelease': tx['commitOrRollbackAndReleaseMicros'],
                'mergeOther': merge['micros'] - queue - preparation - tx['micros'],
                'afterMergeBeforeCapture': cap_start - end,
                'captureConnectionAndBegin': cap_tx['connectionWaitAndBeginMicros'],
                'captureSql': cap_tx['sqlWallMicros'],
                'captureNonSql': cap_tx['unattributedBodyMicros'],
                'captureCommitAndRelease': cap_tx['commitOrRollbackAndReleaseMicros'],
                'captureOther': cap_end - cap_start - cap_tx['micros'],
                'afterCaptureBeforeYield': sent - cap_end,
                'transportAndClientResidual': measured['writeToAllPeersMicros'] - (sent - begin),
            }
            rows.append({
                'user': user,
                'round': sequence,
                'writer': measured['writer'],
                'sourceRequest': source[0],
                'sourceBatch': source[1],
                'peerRequest': peer[0],
                'peerBatch': peer[1],
                'totalMicros': measured['writeToAllPeersMicros'],
                'serverPathMicros': sent - begin,
                'parts': parts,
                'mergeTransaction': tx,
                'captureTransaction': cap_tx,
            })

    expected = sum(user in receipt['sampleUserIndices'] for user, _ in rounds)
    assert len(rows) == expected and expected > 0
    invalid = [r for r in rows if any(v < 0 for v in r['parts'].values()) or abs(sum(r['parts'].values()) - r['totalMicros']) > 2]
    result = {
        'label': label,
        'status': 'rejected' if invalid else 'valid',
        'matching': 'Explicit authored benchmark round and writer, request and numbered batch. Same-isolate monotonic timestamps; no wall-clock conversion or ordinal pairing.',
        'populationLatency': distribution([r['writeToAllPeersMicros'] for r in rounds.values()]),
        'sampledLatency': distribution([r['totalMicros'] for r in rows]),
        'invalidPartitions': len(invalid),
        'collectorRetries': collector['errors'],
        'rows': rows,
        'limits': 'SQL includes transport and scheduling. Connection includes BEGIN. Residual includes client work and both network directions. Sample overhead is measured separately. No invalid residual is clamped.',
    }
    if not invalid:
        result['meanPartsMs'] = {key: statistics.mean(r['parts'][key] for r in rows) / 1000 for key in rows[0]['parts']}
        ordered = sorted(rows, key=lambda r: r['totalMicros'])
        result['sampledP95Round'] = ordered[math.ceil(len(ordered) * .95) - 1]
    (root / (label + '-correlated.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ['rows', 'sampledP95Round']}, indent=2))
    assert not invalid, f'{len(invalid)} invalid partitions retained'


if __name__ == '__main__':
    analyze(Path(sys.argv[1]), sys.argv[2])
