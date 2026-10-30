"""Combine completed tier results while retaining separate campaign identities."""

import argparse
import json
import os
from pathlib import Path

from idle_capacity_report import NAMES, PREVIOUS_IDLE, PREVIOUS_URL, number


def read(path):
    return json.loads(path.read_text())


def control_summary(directory, destination):
    directory = Path(directory)
    relative = os.path.relpath(directory, destination)
    rows = {row['label']: row for row in read(directory / 'results.json')}
    admissions = read(directory / 'admission-controls.json')
    compression = read(directory / 'compression-controls.json')
    lines = ['', '## Fresh-instance follow-ups', '',
        'The default-compression sweep above reuses each instance between '
        'cases. These additional cases start on fresh instances and retain '
        'the same server executable. They are separate measurements, not '
        'replacements for the failed sweep cases.', '',
        '| Control | Target | Opened / resumed | Full pass | Failure phase | Peak cgroup MiB |',
        '|---|---:|---:|---|---|---:|',
    ]
    for control in admissions + compression:
        row = rows[control['label']]
        name = NAMES[row['size']]
        description = name + (' cold, 32 opens, compressed' if control in admissions else
                              f" compression {control['mode']}")
        lines.append(f"| {description} | {row['connections']:,} | {row['opened']:,} / {row['resumed']:,} | "
                     f"{'Yes' if row['passed'] else 'No'} | {row['failurePhase'] or '—'} | "
                     f"{number(row['peakCgroupBytes'] / 1024**2)} |")

    lines += ['',
        'The XL/XXL confirmations use 32 simultaneous opens instead of 64 and '
        'keep ordinary WebSocket compression. They test a different admission '
        'condition; any setup failure still does not determine established '
        'idle capacity.', '',
        'The two Small 256-connection cases change only compression '
        'negotiation between fresh instances. TLS, authentication, the '
        'streaming protocol, opening rate, idle interval and probing remain '
        'the same.', '',
    ]
    paired = {c['mode']: rows[c['label']] for c in compression if c['connections'] == 256}
    if set(paired) == {'enabled', 'disabled'} and all(row['passed'] for row in paired.values()):
        enabled, disabled = (paired[mode]['peakCgroupBytes'] for mode in ['enabled', 'disabled'])
        reduction = (1 - disabled / enabled) * 100
        lines += [
            f'The 256-stream Cloud controls both passed. Peak container memory '
            f'fell from {enabled / 1024**2:.1f} to {disabled / 1024**2:.1f} MiB '
            f'({reduction:.1f}% lower) without compression. This includes the '
            'process baseline and the complete case; it is not a per-socket '
            'heap allocation measurement.', '',
        ]

    for control in compression:
        row = rows[control['label']]
        failures = control['firstTransportFailures']
        if row['passed'] or not failures:
            continue
        first = failures[0]
        lines += [
            f"The {row['connections']:,}-connection Small test with compression "
            f"{control['mode']} failed during {row['failurePhase']}. Its first "
            f"recorded close code was `{first.get('webSocketCloseCode')}` after "
            f"HTTP upgrade `{first.get('upgradeHttpStatus')}`. Peak sampled "
            f"container memory was {row['peakCgroupBytes'] / 1024**2:.1f} MiB "
            f"of {row['memoryLimitBytes'] / 1024**2:.0f} MiB. Memory savings "
            'therefore did not establish a reliable larger idle capacity; '
            'the transport failure needs separate investigation.', '',
        ]

    lines += [
        f'See [the control report]({relative}/README.md) for exact failure '
        'messages, negotiated headers, phase memory, full latency statistics '
        'and restoration evidence. Compression remains a diagnostic option; '
        'active sync traffic and bandwidth tradeoffs were not benchmarked.', '',
    ]
    return lines


def render(destination, campaigns, controls=None):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    sources = []
    tiers = {}
    opening_controls = []
    passing_cases = []

    for directory in map(Path, campaigns):
        manifest = read(directory / 'manifest.json')
        rows = read(directory / 'results.json')
        relative = os.path.relpath(directory, destination)
        source = {'directory': relative, 'manifest': manifest}
        sources.append(source)
        passing_cases.extend({'directory': relative, **row} for row in rows if row['passed'])
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
        '**These are demonstrated full-lifecycle passes, not exact maximum '
        'idle capacities.** Opening failures, retained memory between cases '
        'and occasional disconnects stopped parts of the search. The '
        'non-monotonic results do not show that XXL has less hardware '
        'capacity than Large.', '',
        '## Observed operating points', '',
        '| Tier | RAM MiB | Visible CPU cores | Concurrent opens | 45 s full pass | 5 min full pass | Resume median / p95 ms | Prior Offline Sync strict pass |',
        '|---|---:|---:|---:|---:|---:|---:|---:|',
    ]

    for size, name in NAMES.items():
        value = tiers.get(size)
        if value is None:
            lines.append(f'| {name} | — | — | — | Pending | Pending | — | {PREVIOUS_IDLE[size]:,} |')
            continue
        tier = value['tier']
        selected = value['selected']
        if selected is None:
            raise ValueError('A completed tier has no passing five-minute trial: ' + size)
        latency = selected['probeLatency']
        opening = selected['openWorkers'] * selected.get('openConcurrencyPerWorker', 1)
        lines.append(f"| {name} | {selected['memoryLimitBytes'] // 1024**2:,} | {selected['visibleCpuQuota']} | {opening} | "
                     f"{tier['largestShortPass']:,} | {tier['longIdleQualified']:,} | "
                     f"{number(latency['medianMs'])} / {number(latency['p95Ms'])} | {PREVIOUS_IDLE[size]:,} |")

    lines += ['', '## Five-minute resume latency', '',
        'These are exact per-connection echo durations in milliseconds, including '
        'the client-to-Cloud network path. They are not durable sync-round times.', '',
        '| Tier | Responses | Min | Median | Mean | p95 | Max |',
        '|---|---:|---:|---:|---:|---:|---:|',
    ]
    for size, name in NAMES.items():
        value = tiers.get(size)
        if value is None:
            continue
        latency = value['selected']['probeLatency']
        lines.append(f"| {name} | {latency['count']:,} | " + ' | '.join(
            number(latency[key]) for key in ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs']) + ' |')

    if passing_cases:
        worst = max(passing_cases, key=lambda row: row['probeLatency']['maxMs'])
        lines += ['',
            f"Across all completed passing trials, the worst recorded echo was "
            f"{number(worst['probeLatency']['maxMs'])} ms in `{worst['label']}` "
            f"([case evidence]({worst['directory']}/README.md)). A capacity pass "
            'does not certify a sub-second latency SLA. Rare long delays are '
            'retained; their source has not been isolated.',
        ]

    if controls:
        control_manifest = read(Path(controls) / 'manifest.json')
        if control_manifest['serverExecutableSha256'] not in executables:
            raise ValueError('The controls used a different server executable.')
        lines += control_summary(controls, destination)

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
        'Session persistence/console logging are disabled. The pinned Serverpod '
        'client sends a JSON ping every 20 seconds and uses a 40-second '
        'inactivity timeout; those keepalives continue during the idle interval. '
        'SQL-free metrics are collected every five '
        'seconds. Generator limitations fail a trial rather than being '
        'reported as server capacity. Visible CPU quotas come from the '
        'container cgroup; hidden ancestor limits remain unverified.', '',
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
        'controlDirectory': os.path.relpath(controls, destination) if controls else None,
    }, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--controls')
    parser.add_argument('campaigns', nargs='+')
    args = parser.parse_args()
    render(args.output, args.campaigns, args.controls)
