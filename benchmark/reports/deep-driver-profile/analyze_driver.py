import collections
import json
import sys
import statistics
from pathlib import Path

ROOT = Path(sys.argv[1]) if __name__ == "__main__" and len(sys.argv) > 1 else Path(__file__).parent
STEPS = [
    ('preparation', 'executeStart', 'scheduled'),
    ('operationQueue', 'scheduled', 'operationReady'),
    ('encodeAndSend', 'operationReady', 'sent'),
    ('waitFirstMessage', 'sent', 'firstMessage'),
    ('firstMessageToReady', 'firstMessage', 'ready'),
    ('completeAndReturn', 'ready', 'executeEnd'),
]


def query_parts(query):
    marks = query['marksMicros']
    assert query['asynchronousCodec'] is False
    assert query['droppedMessages'] == 0
    parts = {name: marks[b] - marks[a] for name, a, b in STEPS}
    assert all(v >= 0 for v in parts.values()), parts
    assert sum(parts.values()) == marks['executeEnd']
    return parts


def summarize(queries, rounds):
    total = collections.Counter()
    cpu = collections.Counter()
    for q in queries:
        total.update(query_parts(q))
        cpu.update(q['threadCpuMicros'])
    return {
        'calls': len(queries), 'rounds': rounds,
        'callsPerRound': len(queries) / rounds,
        'meanWallPerRoundMs': {k: v / rounds / 1000 for k, v in total.items()},
        'meanWallPerCallMs': {k: v / len(queries) / 1000 for k, v in total.items()},
        'cpuCounterCaveat': 'Cloud increments are quantized in 10000 microseconds; retained as observations, not usable per-function CPU costs.',
        'measuredCpuPerRoundMs': {k: v / rounds / 1000 for k, v in cpu.items()},
    }


def analyze(label):
    d = json.loads((ROOT / f'{label}-correlated.json').read_text())
    assert d['status'] == 'valid' and d['invalidPartitions'] == 0
    rows = d['rows']
    events = [json.loads(line) for line in (ROOT / f'{label}-server.jsonl').read_text().splitlines()]
    merges = {(e['requestId'], e['batchId']): e for e in events if e['type'] == 'mergeTrace'}
    pre_capture = []
    excluded_background = 0
    span_names = {(e['requestId'], e['event']['spanId']): e['event']['name']
                  for e in events if e['type'] == 'syncTimeline' and e['event']['kind'] == 'start'}
    merge = []
    capture = []
    boundaries = []
    phases = collections.defaultdict(list)
    residuals = collections.defaultdict(list)
    for row in rows:
        merge_event = merges[row['sourceRequest'], row['sourceBatch']]
        left = merge_event['processOriginMicros'] + merge_event['endMicros']
        cap = row['captureTransaction']
        right = cap['processOriginMicros'] + cap['startMicros']
        queries = [e for e in events if e['type'] == 'driverQuery'
                   and e['requestId'] == row['peerRequest']
                   and e['parentId'] in (None, cap['parentId'])
                   and left < e['processOriginMicros'] + e['atMicros'] < right]
        background = [e for e in events if e['type'] == 'driverQuery'
                      and e['requestId'] == row['peerRequest']
                      and e['parentId'] not in (None, cap['parentId'])
                      and left < e['processOriginMicros'] + e['atMicros'] < right]
        assert all(span_names[(e['requestId'], e['parentId'])] == 'sync.recoveryScan' for e in background)
        excluded_background += len(background)
        assert len(queries) == 2, (row['round'], len(queries))
        assert all(q['processOriginMicros'] + q['atMicros'] - q['marksMicros']['executeEnd'] >= left for q in queries)
        pre_capture.extend(queries)
        for name, expected, destination in [('mergeTransaction', 10, merge),
                                             ('captureTransaction', 3, capture)]:
            tx = row[name]
            assert tx['droppedDriverQueries'] == 0
            qs = tx['driverQueries']
            assert len(qs) == expected + 2
            assert qs[0]['command'] == 'BEGIN'
            assert qs[-1]['command'] == 'COMMIT'
            for q in qs:
                query_parts(q)
            destination.extend(qs[1:-1])
            boundaries.extend([qs[0], qs[-1]])
            residuals[name + '.outsideBegin'].append(tx['connectionWaitAndBeginMicros'] - qs[0]['marksMicros']['executeEnd'])
            residuals[name + '.outsideCommit'].append(tx['commitOrRollbackAndReleaseMicros'] - qs[-1]['marksMicros']['executeEnd'])
            residuals[name + '.adapterOutsideDriver'].append(tx['sqlWallMicros'] - sum(q['marksMicros']['executeEnd'] for q in qs[1:-1]))
            if name == 'mergeTransaction':
                for q in qs[1:-1]:
                    phases[q['phase']].append(q)
    return {
        'label': label,
        'recoveryScanQueriesExcludedFromCriticalPath': excluded_background,
        'populationLatency': d['populationLatency'],
        'sampledLatency': d['sampledLatency'],
        'meanPartsMs': d['meanPartsMs'],
        'merge': summarize(merge, len(rows)),
        'capture': summarize(capture, len(rows)),
        'boundaries': summarize(boundaries, len(rows)),
        'membershipAndSpaceReads': summarize(pre_capture, len(rows)),
        'allCriticalDriverCalls': summarize(merge + capture + boundaries + pre_capture, len(rows)),
        'mergePhases': {k: summarize(v, len(rows)) for k, v in phases.items()},
        'residualMeanMs': {k: statistics.mean(v) / 1000 for k, v in residuals.items()},
        'residualMinMs': {k: min(v) / 1000 for k, v in residuals.items()},
    }


if __name__ == '__main__':
    out = [analyze(label) for label in ['deep-medium-profile', 'deep-medium-lowrate', 'deep-xxlarge-profile', 'deep-medium-queue-profile']
           if (ROOT / f'{label}-correlated.json').exists()]
    (ROOT / 'driver-analysis.json').write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps(out, indent=2))
