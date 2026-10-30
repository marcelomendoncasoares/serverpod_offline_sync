"""Independently audit completed idle-capacity observations without Cloud calls."""

import argparse
import json
import math
from pathlib import Path
import statistics


def read(path):
    return json.loads(Path(path).read_text())


def require(condition, message):
    if not condition:
        raise ValueError(message)


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    return {'count': len(values), 'minMs': values[0] / 1000,
            'medianMs': statistics.median(values) / 1000,
            'meanMs': statistics.mean(values) / 1000,
            'p95Ms': values[math.ceil(len(values) * .95) - 1] / 1000,
            'maxMs': values[-1] / 1000}


def audit(config_path):
    config = read(config_path)
    evidence = Path(config['evidenceDirectory'])
    report = Path(config['reportDirectory'])
    rows = read(report / 'results.json')
    state = read(evidence / 'campaign.json')
    require({r['label'] for r in rows} == set(state['cases']), 'Exported case set differs.')
    all_samples = [json.loads(line) for line in (report / 'samples.jsonl').read_text().splitlines()]
    raw_count = 0
    passed_count = 0
    missing_summaries = []
    for row in rows:
        label = row['label']
        events = [json.loads(line) for line in
                  (evidence / 'runs' / label / 'events.jsonl').read_text().splitlines()]
        receipt = read(evidence / 'cases' / f'{label}.json')
        if not receipt.get('summary'):
            missing_summaries.append(label)
        require(row['serverExecutableSha256'] == state['serverExecutableSha256'], label + ': server changed')
        require(row['clientSha256'] == config['clientSha256'], label + ': client changed')
        require(row['passed'] == receipt['passed'], label + ': changed verdict')
        selected = [e for e in events if e['type'] in ['opened', 'probe', 'workerSample', 'workerIdle']]
        exported = [{k: v for k, v in e.items() if k != 'case'}
                    for e in all_samples if e['case'] == label]
        require(selected == exported, label + ': raw exported observations differ')
        for kind, key in [('opened', 'openLatency'), ('probe', 'probeLatency')]:
            items = [e for e in events if e['type'] == kind]
            raw_count += len(items)
            expected = distribution([e['micros'] for e in items])
            actual = row[key]
            if actual is None and not receipt.get('summary') and not row['passed']:
                # An operator interruption can retain raw events without the
                # client's terminal summary. It is never a passing trial.
                continue
            require((expected is None) == (actual is None), label + ': missing distribution')
            if expected is not None:
                for field, value in expected.items():
                    require(math.isclose(value, actual[field], rel_tol=1e-12, abs_tol=1e-8),
                            label + ': wrong ' + key + '.' + field)
            if row['passed']:
                require(len(items) == row['connections'], label + ': incomplete receipts')
                require({e['connection'] for e in items} == set(range(row['connections'])),
                        label + ': incomplete connection identities')
        if not row['passed']:
            continue
        passed_count += 1
        require(row['cleanupVerified'] and row['idleCompleted'], label + ': lifecycle incomplete')
        require(not row['streamFailures'] and not row['sampleFailures'], label + ': hidden failure')
        require(row['generator']['guardReason'] is None and not row['generator']['errors'],
                label + ': generator limitations')
        samples = [e for e in events if e['type'] == 'serverSample']
        require(len({s['server']['instanceId'] for s in samples}) == 1, label + ': instance changed')
        require(all(s['streams']['open'] == 0 for s in samples), label + ': Offline Sync was active')
        boundaries = receipt['summary']['boundaries']
        count = row['connections']
        for phase in ['open', 'idle', 'probe']:
            require(boundaries[phase]['transport']['open'] == count, label + ': missing server streams')
        before = boundaries['before']['transport']
        after = boundaries['cleanup']['transport']
        require(before['open'] == after['open'] == 0, label + ': dirty lifecycle boundary')
        require(after['openedTotal'] - before['openedTotal'] == count, label + ': hidden reconnect')
        require(after['closedTotal'] - before['closedTotal'] == count, label + ': missing close')
        require(after['messagesTotal'] - before['messagesTotal'] == count * 2, label + ': unexpected application messages')
        idle = [e for e in events if e['type'] == 'workerIdle']
        require(len(idle) == row['workers'], label + ': missing worker idle interval')
        require(all(e['micros'] >= row['idleSeconds'] * 1000000 - 100000 for e in idle),
                label + ': idle interval shortened')
    result = {'casesAudited': len(rows), 'passingCasesAudited': passed_count,
              'rawTimingObservationsAudited': raw_count,
              'allExportedSamplesMatchRawEvents': True,
              'exactStreamIdentitiesCountsAndMessagesChecked': True,
              'buildIdentitiesChecked': True,
              'casesWithoutClientSummary': missing_summaries,
              'restorationRequired': state.get('restorationRequired')}
    (report / 'MEASUREMENT_AUDIT.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    print(json.dumps(audit(parser.parse_args().config), indent=2))
