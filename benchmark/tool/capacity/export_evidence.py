"""Export benchmark facts without credentials, host paths, or private archives."""

import json
from pathlib import Path

from campaign import ROOT, assess, read
from guidance import render

from settings import CONFIG, sha256

DESTINATION = Path(CONFIG.get('reportDirectory', ROOT / 'report'))


def export():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    state = read(ROOT / 'campaign-state.json')
    results = []
    rounds = []
    for label in state['runs']:
        receipt = read(ROOT / (label + '.json'))
        if 'exitCode' not in receipt:
            continue
        result = assess(label)
        options = result.get('options') or {}
        result['options'] = {k: v for k, v in options.items() if k not in ['target', 'data-dir', 'directory']}
        result['failures'] = [str(s).replace(str(ROOT), '<evidence>') for s in result['failures']]
        interpretation = ROOT / (label + '-interpretation.json')
        if interpretation.exists():
            result['interpretation'] = read(interpretation)
        results.append(result)
        event_path = Path(receipt['output']) / 'events.jsonl'
        if event_path.exists():
            for line in event_path.read_text().splitlines():
                event = json.loads(line)
                if event.get('type') == 'round':
                    rounds.append({'label': label, **event})

    manifest = {
        'status': state['status'],
        'stoppingPolicy': state.get('stoppingPolicy'),
        'sourceRevision': state['sourceRevision'],
        'baseRevision': state['baseRevision'],
        'branch': state['branch'],
        'nativeTls': True,
        'pipelining': False,
        'serverExecutableSha256': state['nativeExecutableSha256'],
        'clientBuilds': state.get('clientBuilds', [{'sha256': results[0]['clientSha256'], 'sourceRevision': state['sourceRevision']}] if results else []),
        'dartVersion': state.get('dartVersion', CONFIG.get('dartVersion')),
        'databasePoolLimit': 100,
        'mergeConcurrencyLimit': 50,
        'commitHints': False,
        'persistentSessionLogging': False,
        'consoleSessionLogging': False,
        'diagnostics': 'One sampled user plus existing one-second process samples; same configuration across runs.',
        'measurements': 'Continuous established streams; local write start until exact rows are applied on every peer.',
        'correctness': 'Full journal comparison against server and every replica without repair syncs; clean stream and transaction drainage.',
        'databasePlacement': state.get('databasePlacement', CONFIG.get('databasePlacement')),
        'memoryCaveat': 'Cgroup allocation is authoritative for container budget; process RSS includes shared mappings.',
        'limits': 'Passing/failing workload brackets, not an unconditional maximum device count. Exploratory runs require repetitions for sizing recommendations.',
        'restorationRequired': (
            state['restorationRequired']
            or state.get('originalDeploymentRestorationRequired', False)
        ),
        'candidateRestorationRequired': state['restorationRequired'],
        'originalDeploymentRestorationRequired': state.get('originalDeploymentRestorationRequired', False),
        'dependencies': read(ROOT / 'deployment-manifest.json')['dependencies'],
        'runnerFiles': {
            path.name: sha256(path) for path in sorted(Path(__file__).parent.glob('*.py'))
        },
    }
    (DESTINATION / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (DESTINATION / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    skipped_path = ROOT / 'skipped-cases.json'
    skipped = read(skipped_path) if skipped_path.exists() else []
    (DESTINATION / 'skipped-cases.json').write_text(json.dumps(skipped, indent=2) + '\n')
    observation_paths = [ROOT / 'large-round-observation.json']
    observations = [read(path) for path in observation_paths if path.exists()]
    (DESTINATION / 'observations.json').write_text(json.dumps(observations, indent=2) + '\n')
    with (DESTINATION / 'rounds.jsonl').open('w') as stream:
        for row in rounds:
            stream.write(json.dumps(row, separators=(',', ':')) + '\n')

    document = [
        '# Native TLS capacity measurements', '',
        'Status: ' + state['status'] + '. Coverage is limited to the cases listed below; unmeasured cells have no inferred result.', '',
        'Native TLS is enabled; pipelining is disabled. These are end-to-end continuous-sync rounds on established streams. '
        'A correctness pass means every expected row converged and teardown drained. Keeping up with the offered rate is a separate verdict.', '',
        'Latency values are milliseconds. Median is the arithmetic sample median; p95 uses nearest rank. '
        'Failed runs retain their completed observations, which must not be interpreted as successful-run latency.', '',
        '| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|',
    ]
    for result in results:
        options = result.get('options') or {}
        load = result.get('load') or {}
        lat = result['latency']
        values = [f'{lat[k]:.1f}' for k in ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs']] if lat else ['—'] * 5
        document.append('| ' + ' | '.join([
            result['label'],
            f"{load.get('connectedDevices', '?')} / {load.get('participatingDevices', '?')}",
            str(options.get('rows', '?')), str(lat['count'] if lat else 0),
            *values, f"{result['correct']} / {result['keptUp']}",
        ]) + ' |')
    document += ['', 'The adjacent JSON files contain raw round timings, observed overlap, offered and achieved rates, '
                 'schema/workload options, memory, generator observations, sampled merge SQL counts, failures, and exact build identities.', '']
    document += [
        '## Idle connections and resumed delivery', '',
        'Each idle test warms both directions, holds established streams for 45 seconds, then sends one fresh row per user. '
        'Probe concurrency is bounded to eight users. A startup failure does not establish a steady-state connection ceiling.', '',
        '| Run | Target streams | Started | Idle hold completed | Probes | Probe median / mean / p95 (ms) | Peak cgroup MiB | Correct |',
        '|---|---:|---:|---|---:|---|---:|---|',
    ]
    for result in results:
        load = result.get('load') or {}
        if load.get('activeUsers') != 0:
            continue
        latency = result['probeLatency']
        display = ' / '.join(f'{latency[k]:.1f}' for k in ['medianMs', 'meanMs', 'p95Ms']) if latency else '—'
        peak = result['peakCgroupBytes']
        document.append('| ' + ' | '.join([
            result['label'], str(load.get('connectedDevices', '?')),
            str(result['startedStreamEvents']), str(result['exerciseCompleted']),
            str(latency['count'] if latency else 0), display,
            f'{peak / 1024**2:.1f}' if peak else '—', str(result['correct']),
        ]) + ' |')
    document += ['', 'Restart causes require separate evidence. Memory samples alone do not establish an OOM kill. See each failure phase and recovery receipt.', '']
    if skipped:
        document += [
            '## Skipped heavier cases', '',
            'These cases were not measured because an equal or lighter comparable load did not pass. '
            'They do not establish a measured capacity limit. See `skipped-cases.json` for parameters and blocking verdicts.', '',
            '| Skipped case | Blocking measurement |', '|---|---|',
            *[f"| {case['id']} | {case['blockedBy']} |" for case in skipped], '',
        ]
    (DESTINATION / 'README.md').write_text('\n'.join(document))
    render(DESTINATION)
    print(json.dumps({'exportedRuns': len(results), 'exportedRounds': len(rounds), 'destination': str(DESTINATION)}))


if __name__ == '__main__':
    export()
