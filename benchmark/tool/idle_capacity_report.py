"""Render an idle-stream capacity report from its exported observations."""

import argparse
import json
from pathlib import Path


NAMES = {'small': 'Small', 'medium': 'Medium', 'large': 'Large',
         'xlarge': 'XL', 'xxlarge': 'XXL'}
PREVIOUS_IDLE = {'small': 256, 'medium': 1024, 'large': 128,
                 'xlarge': 512, 'xxlarge': 1024}
PREVIOUS_URL = ('https://github.com/marcelomendoncasoares/serverpod_offline_sync/blob/'
                'perf/checkpoint-capacity-validation/benchmark/reports/'
                'revision-checkpoint-capacity-combined-2026-10-29/CAPACITY_GUIDE.md')


def number(value, places=1):
    return '—' if value is None else f'{value:,.{places}f}'


def render(directory):
    directory = Path(directory)
    rows = json.loads((directory / 'results.json').read_text())
    tiers = json.loads((directory / 'tiers.json').read_text())
    manifest = json.loads((directory / 'manifest.json').read_text())
    lines = [
        '# Ordinary Serverpod idle streaming capacity', '',
        'This experiment measures a regular authenticated bidirectional Serverpod '
        'method stream. Each connection echoes a unique String before and after '
        'inactivity. The endpoint does no Offline Sync work and executes no SQL. '
        'Every simulated device has its own Client and WebSocket.', '',
        'All counts are observed operating points on one instance. Passing the '
        'largest attempted count establishes a lower bound; setup, transport and '
        'close failures do not by themselves identify a hardware limit.', '',
        '## Comparison with the earlier sync campaign', '',
        f'The [previous Offline Sync report]({PREVIOUS_URL}) used a 45-second idle '
        'interval followed by durable changes between two devices per user. '
        'The regular-stream control screens the same idle duration and also '
        'qualifies selected counts for five minutes. Its echo latency is not a '
        'sync-round latency.', '',
        '| Tier | Offline Sync: strict 45 s pass | Regular stream: 45 s pass | '
        'Regular stream: 5 min pass | 5 min probe median / p95 ms | Next unsuccessful target |',
        '|---|---:|---:|---:|---:|---|',
    ]
    if (directory / 'OPENING_RATE_TRANSITION.md').exists():
        lines[2:2] = [
            'This is the initial Small/Medium campaign plus three slower Large '
            'controls. See [the opening-rate transition](OPENING_RATE_TRANSITION.md) '
            'for the clean handoff to the continued larger-tier campaign.', '',
        ]
    for tier in tiers:
        size = tier['size']
        selected = next((r for r in rows if r['size'] == size and r['passed'] and
                         r['idleSeconds'] == manifest['qualificationIdleSeconds'] and
                         r['connections'] == tier['longIdleQualified']), None)
        latency = selected['probeLatency'] if selected else {}
        failure = tier['firstUnsuccessfulTarget']
        failure_text = f'{failure:,}' if failure is not None else 'None within tested range'
        if failure is not None:
            failed = [r for r in rows if r['size'] == size and not r['passed'] and
                      r['connections'] == failure]
            if failed:
                failure_text += f" ({failed[-1]['failurePhase'] or 'observation'})"
        lines.append(f"| {NAMES[size]} | {PREVIOUS_IDLE[size]:,} | "
                     f"{tier['largestShortPass']:,} | {number(tier['longIdleQualified'], 0)} | "
                     f"{number(latency.get('medianMs'))} / {number(latency.get('p95Ms'))} | {failure_text} |")
    lines += ['',
        'The prior 1,024-device strict maximum was not proof of a 1,024-stream '
        'framework limit: its XXL 2,048-device trial delivered and verified all '
        'users, then failed during close. Likewise, the prior report did not '
        'establish a 200-row batch limit: City workloads with 1,000 rows kept up '
        'on Large, XL and XXL at lower concurrency. Throughput, correctness and '
        'lifecycle success are separate measurements.', '',
        '## Every measured case', '',
        'Latencies are milliseconds from sending a resume message to receiving '
        'the identical message on the same connection. All streams are probed, '
        'with at most eight simultaneous probes. Warmup/setup is excluded.', '',
        '| Case | Verdict / phase | Opened / resumed | Idle s | Min | Median | Mean | p95 | Max | Peak cgroup MiB |',
        '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|',
    ]
    for row in rows:
        latency = row.get('probeLatency') or {}
        verdict = 'PASS' if row['passed'] else 'FAIL / ' + str(row.get('failurePhase'))
        memory = row.get('peakCgroupBytes')
        lines.append(f"| {row['label']} | {verdict} | {row.get('opened')} / {row.get('resumed')} | "
                     f"{row['idleSeconds']} | " + ' | '.join(number(latency.get(k)) for k in
                     ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs']) +
                     f" | {number(None if memory is None else memory / 1024**2)} |")
    lines += ['', '## Interpretation and controls', '',
        '- Setup is bounded to the per-tier opening-worker counts multiplied by '
        'openConcurrencyPerWorker in manifest.json (one if omitted). Connection establishment '
        'does not include Offline Sync startup or a user lookup in PostgreSQL.',
        '- Authentication uses the existing benchmark admin credential. No replica '
        'database or per-user domain data is created by these clients. The server '
        'still loads the benchmark application; this removes Offline Sync from '
        'the measured endpoint, not from the process baseline.',
        '- Normal Serverpod keepalives remain enabled. There are no application '
        'messages during the idle interval, no automatic reconnects, and no retries.',
        '- SQL-free server metrics are sampled every five seconds. The earlier '
        'campaign used a separate diagnostics collector and periodic database '
        'metrics; monitoring overhead is not identical.',
        '- Shutdown is bounded to 64 simultaneous closes. The earlier sync runner '
        'closed all devices together. A transport-control shutdown pass therefore '
        'does not resolve a possible burst-teardown defect in the sync campaign.',
        '- The server executable, Dart client executable and source revision are '
        'recorded in [manifest.json](manifest.json). Serverpod and driver dependencies '
        'stay pinned. PostgreSQL TLS is native and pipelining remains disabled, '
        'although the echo endpoint does not use the database.',
        '- [results.json](results.json) preserves all verdicts, failures, actual '
        'server connection counts and generator observations. [samples.jsonl](samples.jsonl) '
        'preserves every open/probe timing and client resource sample. '
        '[resource-boundaries.json](resource-boundaries.json) records memory, '
        'file descriptors and stream counts at each lifecycle boundary.',
        '- Cases on a tier reuse the instance until a restart or resize. Some '
        'opening failures occurred with memory still high after the preceding '
        'case closed. A five-minute qualification can therefore fail during '
        'opening even after the same count passed a shorter case. The two '
        'columns are observed full-lifecycle passes, not independently measured '
        'maximum idle capacities.',
        '- A changed server instance and high sampled memory support memory '
        'pressure as a candidate cause. No orchestrator OOM termination reason '
        'was captured. High memory after close also does not by itself prove '
        'a leak: garbage collection and allocator retention were not separated.',
        '- Failed-case opened counts are successful warmup receipts, not '
        'necessarily simultaneous residency. Error and EOF can both be counted '
        'for one connection, and shutdown following the first fault can emit '
        'additional failure events. Do not interpret event counts as independent '
        'connection failures.',
        '- More idle streams do not imply the same number of simultaneous syncs. '
        'A native endpoint with no database work is a control for transport '
        'capacity, not a substitute for an application workload.', '',
        '## Restoration', '',
        ('Restoration remains outstanding; this is an interim report.'
         if manifest.get('restorationRequired') else
         'The campaign restoration flag is clear. Consult the restoration receipt '
         'for the independently verified executable, instance size and cleanup.'), '',
    ]
    (directory / 'README.md').write_text('\n'.join(lines))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report')
    render(parser.parse_args().report)
