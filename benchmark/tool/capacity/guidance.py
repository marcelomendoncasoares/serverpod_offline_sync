"""Summarize observed workloads without extrapolating production capacity."""

import argparse
import json
from collections import defaultdict
from pathlib import Path


SIZES = ['small', 'medium', 'large', 'xlarge', 'xxlarge']
PROFILES = [
    ('full', 'person', 'Person, full registry'),
    ('full', 'town-linked', 'Town with linked parents, full registry'),
    ('city', 'city', 'City, isolated registry'),
]


def usable(result):
    return result.get('correct') is True and result.get('observationsComplete') is True


def active_screens(results, client_sha):
    """Keep the same offered-load screen; longer controls remain separate."""
    selected = []
    for result in results:
        options = result.get('options') or {}
        load = result.get('load') or {}
        if client_sha and result.get('clientSha256') != client_sha:
            continue
        if not all([
            options.get('mode') == 'continuous',
            options.get('write-mode') == 'insert',
            options.get('schedule') == 'spread',
            options.get('period-ms') == 2000,
            options.get('rounds') == 8,
            options.get('payload-bytes') == 128,
            options.get('devices-min') == options.get('devices-max') == 2,
            load.get('activeUsers', 0) > 0,
            load.get('connectedDevices') == load.get('participatingDevices'),
        ]):
            continue
        selected.append(result)
    return selected


def boundary(results, *, subsecond):
    """Do not select a passing repetition when another matching trial failed."""
    groups = defaultdict(list)
    for result in results:
        groups[result['load']['participatingDevices']].append(result)

    passing = []
    for devices, trials in groups.items():
        accepted = all(
            usable(trial)
            and trial.get('keptUp') is True
            and trial.get('latency')
            and (not subsecond or trial['latency']['p95Ms'] < 1000)
            for trial in trials
        )
        if accepted:
            passing.append(devices)

    devices = max(passing, default=None)
    chosen = groups[devices] if devices is not None else []
    # Show the worst p95 repetition rather than the most flattering trial.
    representative = max(chosen, key=lambda r: r['latency']['p95Ms']) if chosen else None
    return {
        'devices': devices,
        'users': devices // 2 if devices is not None else None,
        'offeredRoundsPerSecond': devices / 4 if devices is not None else None,
        'representative': representative,
        'selectedTrials': [r['label'] for r in chosen],
        'allTrials': [r['label'] for r in results],
    }


def build_sizing(results, manifest):
    clients = manifest.get('clientBuilds') or []
    client_sha = clients[-1]['sha256'] if clients else None
    screens = active_screens(results, client_sha)
    rows = sorted({1, 10, 50, 200, 1000, *(r['options']['rows'] for r in screens)})
    cells = []
    for schema, workload, name in PROFILES:
        for count in rows:
            cell = {'schema': schema, 'workload': workload, 'profile': name, 'rows': count, 'sizes': {}}
            for size in SIZES:
                matching = [
                    r for r in screens
                    if r['instanceSize'] == size and r['options']['schema'] == schema
                    and r['options']['workload'] == workload and r['options']['rows'] == count
                ]
                cell['sizes'][size] = {
                    'keptUp': boundary(matching, subsecond=False),
                    'p95BelowOneSecond': boundary(matching, subsecond=True),
                }
            cells.append(cell)

    idle = []
    for size in SIZES:
        trials = [
            r for r in results if r['instanceSize'] == size
            and (r.get('load') or {}).get('activeUsers') == 0
            and r.get('schema') == 'full'
        ]
        passing = [r for r in trials if usable(r) and r.get('exerciseCompleted')]
        best = max(passing, key=lambda r: r['load']['connectedDevices'], default=None)
        idle.append({
            'size': size,
            'largestSuccessfulTrial': best,
            'unsuccessfulTrials': [r for r in trials if not usable(r)],
            'allTrials': [r['label'] for r in trials],
        })
    return {'screenClientSha256': client_sha, 'activeScreens': cells, 'idleConnections': idle}


def render(report):
    report = Path(report)
    results = json.loads((report / 'results.json').read_text())
    manifest = json.loads((report / 'manifest.json').read_text())
    sizing = build_sizing(results, manifest)
    (report / 'sizing.json').write_text(json.dumps(sizing, indent=2) + '\n')
    lines = [
        '# Observed capacity by workload', '',
        'These are measured workload screens, not production capacity guarantees. '
        'Use them to choose a starting configuration, then repeat a sustained test with your schema, '
        'database placement, row sizes, and activity pattern. All results belong to the exact '
        'server and client builds in [manifest.json](manifest.json).', '',
        'Connected devices and devices participating in active rounds are different quantities. '
        'Two devices share one user; each active user offers one round every two seconds, '
        'with at most one round outstanding. The eight-round screens use 128 bytes of seeded '
        'payload per row plus identifiers. Timings include local commit and delivery to every peer. '
        'Participating-device counts describe the offered workload; measured overlap below '
        'counts devices belonging to unfinished rounds. Database transaction concurrency is '
        'a separate measurement.', '',
        '## Observed process budgets', '',
        'These are the visible cgroup limits reported by the running server, not the host '
        'processor count. Unmeasured sizes remain blank.', '',
        '| Size | CPU quota, cores | Memory limit, MiB |',
        '|---|---:|---:|',
    ]
    for size in SIZES:
        matching = [r for r in results if r['instanceSize'] == size]
        cpus = sorted({r['cpuQuota'] for r in matching if r.get('cpuQuota') is not None})
        memory = sorted({r['memoryLimitBytes'] for r in matching if r.get('memoryLimitBytes') is not None})
        lines.append('| ' + ' | '.join([
            size, ', '.join(f'{cpu:g}' for cpu in cpus) or '—',
            ', '.join(f'{limit / 1024**2:g}' for limit in memory) or '—',
        ]) + ' |')

    lines += [
        '', '## Active devices', '',
        'Each cell shows **devices / p95 milliseconds** for the highest tested count that '
        'qualified. The first table additionally requires p95 below one second. Both require '
        'exact convergence, cleanup, complete observations, and keeping up with the offered rate. '
        'If repetitions disagree, that count does not qualify. A dash means no qualifying '
        'measurement; it does not mean zero capacity. Longer controls and different offered '
        'rates are retained in the [complete measurements](README.md).', '',
    ]
    for criterion, title in [
        ('p95BelowOneSecond', 'Kept up with p95 below one second'),
        ('keptUp', 'Kept up, without a latency target'),
    ]:
        lines += [f'### {title}', '', '| Schema profile | Rows | Small | Medium | Large | XL | XXL |',
                  '|---|---:|---:|---:|---:|---:|---:|']
        for row in sizing['activeScreens']:
            values = []
            for size in SIZES:
                cell = row['sizes'][size][criterion]
                result = cell['representative']
                values.append(f"{cell['devices']} / {result['latency']['p95Ms']:.0f}" if result else '—')
            lines.append('| ' + ' | '.join([row['profile'], str(row['rows']), *values]) + ' |')
        lines.append('')

    lines += [
        'Person writes two text fields with nullable relations unpopulated. Town writes its name '
        'and populated City/Person references, with the linked parents seeded before exercise. '
        'City uses one persisted name field in an isolated registry. These profiles sample '
        'different costs; field counts alone do not model an arbitrary application schema.', '',
        '## Connected but idle devices', '',
        'The largest successful trial below completed setup, the idle hold, resumed delivery '
        'and exact verification, and drained cleanly. Failed attempts remain listed with their '
        'phase. A setup failure is not a measured ceiling for already established streams; '
        'a single pass is not a reliability guarantee. Probe traffic is bounded to eight users.', '',
        '| Size | Largest fully verified trial | Probe median / mean / p95 (ms) | Peak cgroup MiB | Unsuccessful target / phase |',
        '|---|---:|---|---:|---|',
    ]
    for row in sizing['idleConnections']:
        best = row['largestSuccessfulTrial']
        latency = best.get('probeLatency') if best else None
        quantiles = ' / '.join(f'{latency[k]:.0f}' for k in ['medianMs', 'meanMs', 'p95Ms']) if latency else '—'
        peak = best.get('peakCgroupBytes') if best else None
        failures = ', '.join(f"{r['load']['connectedDevices']} / {r.get('failurePhase') or 'observation'}" for r in row['unsuccessfulTrials']) or '—'
        lines.append('| ' + ' | '.join([
            row['size'], str(best['load']['connectedDevices']) if best else '—', quantiles,
            f'{peak / 1024**2:.1f}' if peak else '—', failures,
        ]) + ' |')

    lines += [
        '', '## Measured overlap in one-row screens', '',
        'These are the highest qualifying throughput screens from the second active-device '
        'table. The mean and peak count devices involved in unfinished application rounds, '
        'from local write through final peer application. They show how much of the configured '
        'participating population was actually overlapping.', '',
        '| Size / profile | Participating devices | Offered rounds/s | Overlapping devices, mean / peak | p95 ms |',
        '|---|---:|---:|---:|---:|',
    ]
    for size in SIZES:
        for row in sizing['activeScreens']:
            if row['rows'] != 1:
                continue
            cell = row['sizes'][size]['keptUp']
            result = cell['representative']
            if not result:
                continue
            overlap = result.get('concurrency') or {}
            mean = overlap.get('meanParticipatingDevices')
            peak = overlap.get('peakParticipatingDevices')
            display = f'{mean:.1f} / {peak}' if mean is not None and peak is not None else '—'
            lines.append('| ' + ' | '.join([
                size + ' / ' + row['profile'], str(cell['devices']),
                f"{cell['offeredRoundsPerSecond']:g}", display,
                f"{result['latency']['p95Ms']:.0f}",
            ]) + ' |')

    lines += [
        '', '## Mixed connections and sustained controls', '',
        'The controls below use one-row Person writes. They keep latency, correctness, '
        'offered-rate adherence, and observation completeness separate. An incomplete observation '
        'does not erase the client timings, but excludes the run from a matched speedup claim. '
        'A mixed-load pass can establish a connected-device count that a separate setup attempt '
        'failed to establish; inspect both rather than treating the first failure as a ceiling.', '',
        '| Size / control | Connected / active devices | Rounds | Min | Median | Mean | p95 | Max | Correct / kept up / observed |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---|',
    ]
    for size in SIZES:
        for result in results:
            options = result.get('options') or {}
            load = result.get('load') or {}
            if result['instanceSize'] != size or result.get('clientSha256') != sizing['screenClientSha256']:
                continue
            if not all([
                options.get('mode') == 'continuous', options.get('schema') == 'full',
                options.get('workload') == 'person', options.get('rows') == 1,
                options.get('write-mode') == 'insert', options.get('schedule') == 'spread',
                options.get('period-ms') == 2000, load.get('activeUsers', 0) > 0,
            ]):
                continue
            mixed = load['connectedDevices'] > load['participatingDevices']
            sustained = options.get('rounds', 0) >= 150
            if not (mixed or sustained):
                continue
            label = 'mixed' if mixed else 'five-minute offered workload'
            latency = result.get('latency')
            values = [f'{latency[k]:.0f}' for k in ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs']] if latency else ['—'] * 5
            verdict = ' / '.join(str(result.get(k)) for k in ['correct', 'keptUp', 'observationsComplete'])
            lines.append('| ' + ' | '.join([
                size + ' / ' + label,
                f"{load['connectedDevices']} / {load['participatingDevices']}",
                str(latency['count']) if latency else '0', *values, verdict,
            ]) + ' |')

    lines += [
        '', '## Applying the measurements', '',
        'Size for active work and idle connections separately. For example, 1,000 connected '
        'devices with eight devices changing data are not the same workload as 1,000 devices '
        'continuously changing data. Consult the mixed-load controls before combining the two axes.', '',
        'A larger change batch reduces the supported round rate. Populated relation graphs can '
        'add merge work even when the number of changed rows is unchanged. More CPU can help '
        'under concurrent load; lower database latency matters when serial database exchanges '
        'dominate. This campaign does not isolate a database-location change.', '',
        'Use headroom below the observed boundary and test reconnect bursts, longer idle periods, '
        'larger retained datasets, and sustained activity. The finite screens do not measure '
        'multi-instance scaling or establish a maximum concurrent-user promise.', '',
        'The [raw sizing selection](sizing.json) records each selection, its source trial IDs, '
        'and representative overlap, SQL counts, timings and resource measurements. See [results.json](results.json) '
        'for failures and observations excluded from the selection.', '',
    ]
    (report / 'SIZING.md').write_text('\n'.join(lines))
    return sizing


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', required=True)
    arguments = parser.parse_args()
    render(arguments.report)
