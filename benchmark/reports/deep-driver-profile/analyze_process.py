import collections
import json
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if __name__ == "__main__" and len(sys.argv) > 1 else Path(__file__).parent


def analyze(label):
    receipt = json.loads((ROOT / f'{label}.json').read_text())
    profile = json.loads((ROOT / f'{label}-correlated.json').read_text())
    records = [json.loads(s) for s in Path(receipt['serverEvents']).read_text().splitlines()]
    traces = {r['requestId']: r for r in records if r['type'] == 'syncTrace'}
    rows = profile['rows']
    start = min(traces[r['sourceRequest']]['processOriginMicros'] + r['mergeTransaction']['startMicros'] for r in rows) + 3000000
    end = max(r['captureTransaction']['processOriginMicros'] + r['captureTransaction']['endMicros'] for r in rows) - 3000000
    selected = []
    for r in records:
        if r['type'] != 'serverProcess' or not r['activeRequests']:
            continue
        active = r['activeRequests'][0]
        at = active['processOriginMicros'] + active['micros']
        if start <= at <= end:
            selected.append((at, r))
    assert len(selected) > 2
    first, last = selected[0], selected[-1]
    elapsed = (last[0] - first[0]) / 1000000
    user = (last[1]['process']['cpuUserTicks'] - first[1]['process']['cpuUserTicks']) / 100
    system = (last[1]['process']['cpuSystemTicks'] - first[1]['process']['cpuSystemTicks']) / 100
    thread_cpu = collections.Counter()
    for (_, a), (_, b) in zip(selected, selected[1:]):
        if not a['threads']['available'] or not b['threads']['available']:
            continue
        prior = {t['tid']: t for t in a['threads']['threads']}
        for t in b['threads']['threads']:
            if t['tid'] not in prior:
                continue
            previous = prior[t['tid']]
            delta = sum(t[k] - previous[k] for k in ['userTicks', 'systemTicks'])
            assert delta >= 0
            thread_cpu[t['name']] += delta / 100
    lag = [s['loopLag'] for _, s in selected]
    count = sum(w['count'] for w in lag)
    return {
        'label': label, 'windowSeconds': elapsed, 'samples': len(selected),
        'windowDefinition': 'Same-server monotonic span from sampled user exercise merges to last peer capture, trimmed by three seconds at each end; process counters cover all users and diagnostics.',
        'userCpuSeconds': user, 'systemCpuSeconds': system,
        'cpuCores': (user + system) / elapsed,
        'systemFraction': system / (user + system),
        'commonThreadCpuSeconds': dict(thread_cpu),
        'threadCounterLimit': 'Only threads present in consecutive samples are differenced; short-lived thread work may be absent. Runtime names do not identify individual Dart functions.',
        'loopLagSamples': count,
        'loopLagMeanMs': sum(w['meanMicros'] * w['count'] for w in lag) / count / 1000,
        'loopLagMaxMs': max(w['maxMicros'] for w in lag) / 1000,
        'loopLagIntervalMs': 100,
        'maxRssMiB': max(s['process']['rssBytes'] for _, s in selected) / 1024**2,
        'minThreads': min(s['process']['threads'] for _, s in selected),
        'maxThreads': max(s['process']['threads'] for _, s in selected),
        'vmMetrics': list(set(s['vmMetrics'] for _, s in selected)),
    }


if __name__ == '__main__':
    labels = ['deep-medium-control', 'deep-medium-profile', 'deep-medium-controlr', 'deep-medium-lowrate', 'deep-xxlarge-profile', 'deep-medium-queue-profile']
    results = [analyze(label) for label in labels if (ROOT / f'{label}-correlated.json').exists()]
    (ROOT / 'process-analysis.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))
