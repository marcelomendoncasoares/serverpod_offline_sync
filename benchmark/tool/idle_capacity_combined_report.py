"""Combine completed tier results while retaining separate campaign identities."""

import argparse
import json
import os
from pathlib import Path

from idle_capacity_report import NAMES, PREVIOUS_IDLE, PREVIOUS_URL, number


def read(path):
    return json.loads(path.read_text())


def render(destination, campaigns):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    sources = []
    tiers = {}
    opening_controls = []

    for directory in map(Path, campaigns):
        manifest = read(directory / 'manifest.json')
        rows = read(directory / 'results.json')
        relative = os.path.relpath(directory, destination)
        source = {'directory': relative, 'manifest': manifest}
        sources.append(source)
        for row in rows:
            if row['size'] == 'large' and row['connections'] == 1024 and row['idleSeconds'] == 45 and row['passed']:
                opening_controls.append({
                    'directory': relative,
                    'concurrentOpens': row['openWorkers'] * row.get('openConcurrencyPerWorker', 1),
                    'openSeconds': row['phaseSeconds']['open'],
                    'resumeMedianMs': row['probeLatency']['medianMs'],
                })

        for tier in read(directory / 'tiers.json'):
            size = tier['size']
            if size in tiers:
                raise ValueError('Two campaigns claim a completed tier: ' + size)
            selected = next((row for row in rows if row['size'] == size and row['passed']
                             and row['idleSeconds'] == 300
                             and row['connections'] == tier['longIdleQualified']), None)
            tiers[size] = {'tier': tier, 'selected': selected, 'directory': relative}

    executables = {source['manifest']['serverExecutableSha256'] for source in sources}
    if len(executables) != 1:
        raise ValueError('The campaigns used different server executables.')

    lines = [
        '# Serverpod idle-stream capacity: combined findings', '',
        'These are ordinary authenticated Serverpod method streams on the Cloud '
        'benchmark deployment. Each device owns a separate WebSocket and echoes '
        'a unique payload before and after inactivity. The endpoint executes no '
        'SQL and creates no Offline Sync session or local replica.', '',
        ('All five instance sizes have completed their searches.' if len(tiers) == 5 else
         f'Interim report: {len(tiers)} of five instance sizes have completed their searches.'), '',
        '## Observed operating points', '',
        '| Tier | RAM MiB | Concurrent opens | 45 s full pass | 5 min full pass | Resume median / p95 ms | Prior Offline Sync strict pass |',
        '|---|---:|---:|---:|---:|---:|---:|',
    ]

    for size, name in NAMES.items():
        value = tiers.get(size)
        if value is None:
            lines.append(f'| {name} | — | — | Pending | Pending | — | {PREVIOUS_IDLE[size]:,} |')
            continue
        tier = value['tier']
        selected = value['selected']
        if selected is None:
            raise ValueError('A completed tier has no passing five-minute trial: ' + size)
        latency = selected['probeLatency']
        opening = selected['openWorkers'] * selected.get('openConcurrencyPerWorker', 1)
        lines.append(f"| {name} | {selected['memoryLimitBytes'] // 1024**2:,} | {opening} | "
                     f"{tier['largestShortPass']:,} | {tier['longIdleQualified']:,} | "
                     f"{number(latency['medianMs'])} / {number(latency['p95Ms'])} | {PREVIOUS_IDLE[size]:,} |")

    lines += ['',
        'A full pass requires exact responses from every original connection, no '
        'unexpected disconnects or reconnects, stable server identity, complete '
        'observations and zero remaining streams after close. Resume probes are '
        'limited to eight at a time; this measures idle residency and eventual '
        'responsiveness, not thousands of simultaneous active requests.', '',
        'The counts are demonstrated operating points, not universal or exact '
        'maximum capacities. Failed setup or cleanup does not establish an '
        'established-stream limit. The five-minute result can be lower than a '
        '45-second pass because some later trials started with memory retained '
        'from earlier closed connections. Each source report preserves failure '
        'phase, completed opens/resumes, memory and restarts.', '',
        f'The [earlier Offline Sync campaign]({PREVIOUS_URL}) also performed '
        'durable cross-device synchronization. It had different monitoring and '
        'shutdown concurrency. Its strict failures therefore cannot be treated '
        'as a 1,024-stream protocol limit. Its XXL 2,048-device case delivered and '
        'verified changes before failing close. Nor did it establish a 200-row '
        'batch-size cap: 1,000-row City cases kept up at lower concurrency on '
        'Large, XL and XXL.', '',
        '## Memory attribution', '',
        'Small and Medium reproduced opening failures with Offline Sync removed '
        'from the measured endpoint. High sampled memory and server restarts '
        'point to a shared transport/runtime constraint. No orchestrator OOM '
        'termination reason was captured, so an OOM kill is not asserted.', '',
        'The [separate raw Dart WebSocket control](../dart-websocket-memory-2026-10-30/README.md) '
        'used no Serverpod, database or TLS. At 2,048 sockets it measured 504.34 MiB '
        'RSS with WebSocket compression versus 51.32 MiB without it. Actual '
        'compression negotiation and every echo/close were checked. This isolates '
        'a large cost below Serverpod, but is not itself a Cloud capacity result.', '',
        'Memory stayed high after sockets closed in both local and Cloud '
        'observations. Garbage collection, allocator retention and leaks have '
        'not been separated. Disabling compression also trades memory for '
        'additional bytes during active traffic; no sync protocol or TLS change '
        'is implied.', '',
        '## Method and evidence', '',
        'The completed Small/Medium sweep and its three slower Large controls '
        'used eight simultaneous opens. The larger-tier continuation uses 32 '
        'on Large and 64 on XL/XXL to reduce admission time. Its source/build '
        'identity is recorded separately. The server executable, eight resume '
        'probes, 64 closes, payload, authentication and correctness checks stay '
        'the same.', '',
        'The server still loads the benchmark application and its diagnostics; '
        'this is not a stripped-down minimum-memory Serverpod executable. '
        'Session persistence/console logging are disabled. Serverpod keepalives '
        'continue during inactivity. SQL-free metrics are collected every five '
        'seconds. Generator limitations fail a trial rather than being '
        'reported as server capacity.', '',
    ]

    if len(opening_controls) == 2:
        before, after = sorted(opening_controls, key=lambda value: value['concurrentOpens'])
        lines += [
            f"The 1,024-stream Large control opened in {before['openSeconds']:.1f} s "
            f"with {before['concurrentOpens']} concurrent opens and {after['openSeconds']:.1f} s "
            f"with {after['concurrentOpens']}. Resume medians were "
            f"{before['resumeMedianMs']:.1f} and {after['resumeMedianMs']:.1f} ms. "
            'Both passed. This is a test-admission speedup, not a server or '
            'sync-protocol performance gain.', '',
        ]

    for source in sources:
        relative = source['directory']
        lines.append(f'- [{Path(relative).name}]({relative}/README.md): all cases, '
                     'min/median/mean/p95/max, raw observations, independent audit '
                     'and restoration evidence.')

    lines += ['',
        'The separate Cloud compression controls are recorded after the '
        'five-tier search and use fresh instances. Their results must be '
        'read separately from the default-compression capacity table.', '',
    ]
    (destination / 'README.md').write_text('\n'.join(lines))
    (destination / 'manifest.json').write_text(json.dumps({
        'completeTiers': list(tiers), 'serverExecutableSha256': next(iter(executables)),
        'sources': sources, 'openingRateControls': opening_controls,
    }, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('campaigns', nargs='+')
    args = parser.parse_args()
    render(args.output, args.campaigns)
