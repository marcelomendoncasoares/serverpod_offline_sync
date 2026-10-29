"""Combine completed capacity reports without rerunning measurements."""

import argparse
import hashlib
import json
from pathlib import Path

from capacity import guidance


MATCHING_CONFIGURATION = [
    'serverExecutableSha256', 'nativeTls', 'pipelining', 'dartVersion',
    'databasePoolLimit', 'mergeConcurrencyLimit', 'commitHints',
    'persistentSessionLogging', 'consoleSessionLogging', 'databasePlacement',
    'diagnostics', 'measurements', 'correctness', 'dependencies',
]
SOURCE_FILES = [
    'manifest.json', 'results.json', 'rounds.jsonl', 'replay.json',
    'skipped-cases.json', 'observations.json',
    'RESOURCE_ACCOUNTING.md', 'resource-accounting.json',
]


def read(path):
    return json.loads(path.read_text())


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def merge(reports, output, client_sha=None):
    output = Path(output).resolve()
    reports = [Path(report).resolve() for report in reports]
    if not reports or len(set(reports)) != len(reports):
        raise ValueError('Provide distinct source reports.')
    if any(report == output or report.parent != output.parent for report in reports):
        raise ValueError('Source reports and output must be distinct sibling directories.')

    manifests = [read(report / 'manifest.json') for report in reports]
    reference = manifests[0]
    for report, manifest in zip(reports, manifests):
        if manifest.get('status') != 'measured' or manifest.get('sourceReports'):
            raise ValueError('Use completed individual reports: ' + report.name)
        for key in MATCHING_CONFIGURATION:
            if manifest.get(key) is None or manifest[key] != reference.get(key):
                raise ValueError('Incompatible configuration: ' + key + ' in ' + report.name)

    clients = {}
    latest_clients = set()
    for manifest in manifests:
        builds = manifest.get('clientBuilds') or []
        if not builds:
            raise ValueError('A source report has no client build identity.')
        latest_clients.add(builds[-1]['sha256'])
        for build in builds:
            identity = build['sha256']
            existing = clients.get(identity, {})
            if any(existing[key] != build[key] for key in existing.keys() & build.keys()):
                raise ValueError('Conflicting client build metadata: ' + identity)
            clients[identity] = {**existing, **build}

    if client_sha is None:
        if len(latest_clients) != 1:
            raise ValueError('Select --client-sha256 when the reports use different latest clients.')
        client_sha = next(iter(latest_clients))
    if client_sha not in clients:
        raise ValueError('The selected client was not measured.')

    results = {}
    run_labels = {}
    sources = []
    skipped = []
    caveats = []
    for report, manifest in zip(reports, manifests):
        report_results = read(report / 'results.json')
        if not report_results or not (report / 'rounds.jsonl').is_file():
            raise ValueError('A source report lacks results or raw rounds: ' + report.name)
        allowed_clients = {build['sha256'] for build in manifest['clientBuilds']}
        for result in report_results:
            label = result['label']
            if result.get('serverExecutableSha256') != reference['serverExecutableSha256']:
                raise ValueError('Result server differs from its manifest: ' + label)
            if result.get('clientSha256') not in allowed_clients:
                raise ValueError('Result client differs from its manifest: ' + label)
            if not result.get('runId'):
                raise ValueError('Result has no run identity: ' + label)
            if label in results and results[label] != result:
                raise ValueError('Conflicting observations share a label: ' + label)
            if result['runId'] in run_labels and run_labels[result['runId']] != label:
                raise ValueError('One run has multiple labels: ' + result['runId'])
            results[label] = result
            run_labels[result['runId']] = label

        source = {
            'report': report.name,
            'files': {name: digest(report / name) for name in SOURCE_FILES if (report / name).is_file()},
            'labels': [result['label'] for result in report_results],
            'restorationRequiredAtExport': manifest.get('restorationRequired'),
        }
        sources.append(source)
        if (report / 'skipped-cases.json').exists():
            skipped.extend({'sourceReport': report.name, **case} for case in read(report / 'skipped-cases.json'))
        if (report / 'RESOURCE_ACCOUNTING.md').exists():
            caveats.append(
                f'[CPU accounting observations](../{report.name}/RESOURCE_ACCOUNTING.md)'
            )

    # Keep renderer provenance separate from the runners that made measurements.
    manifest = {key: reference[key] for key in MATCHING_CONFIGURATION}
    manifest.update({
        'status': 'measured',
        'sourceReports': sources,
        'sourceRevision': reference.get('sourceRevision'),
        'clientBuilds': [build for identity, build in clients.items() if identity != client_sha]
        + [clients[client_sha]],
        'restorationRequired': any(source['restorationRequiredAtExport'] is not False for source in sources),
        'restorationScope': 'Source snapshots at export time; consult the final deployment restoration audit for current state.',
        'rawRounds': 'Retained in the linked source reports; not duplicated in this aggregate.',
        'sizingRendererSha256': digest(Path(guidance.__file__)),
        'reportCombinerSha256': digest(Path(__file__)),
    })
    lines = [
        '# Combined capacity measurements', '',
        'These completed campaigns used the same server binary and measurement configuration. '
        'All observations, including failed and incomplete trials, remain in [results.json](results.json). '
        'This is a capacity summary, not a before/after speedup comparison.', '',
        f'Sizing selects client `{client_sha}`. Other client builds remain in the source evidence. '
        'See [SIZING.md](SIZING.md) for separate short screens, sustained validation, idle connections, '
        'and measured overlap.', '',
        'Raw round records stay in their source reports. [sources.json](sources.json) records source '
        'file hashes and run labels so the aggregate can be audited without duplicating those files.', '',
        '| Source | Runs | Raw rounds |', '|---|---:|---|',
    ]
    for source in sources:
        name = source['report']
        lines.append(f'| [{name}](../{name}/README.md) | {len(source["labels"])} | [JSONL](../{name}/rounds.jsonl) |')

    caveat = ''
    if caveats:
        caveat = (
            'CPU accounting has unresolved discrepancies in the source observations. '
            'Do not infer an enforced CPU ceiling, headroom, or throttling from those counters. '
            'See ' + ', '.join(caveats) + '.'
        )
        lines.extend(['', caveat])

    lines.extend([
        '', 'Latency is in milliseconds. Failed runs show only completed observations and do not '
        'qualify as passing capacity results. A skipped case has no measured latency.', '',
        '| Run | Connected / active devices | Rows / round | Samples | Min | Median | Mean | p95 | Max | Correct / kept up / observed |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|',
    ])
    for result in results.values():
        load = result.get('load') or {}
        latency = result.get('latency')
        values = [f'{latency[key]:.1f}' for key in ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs']] if latency else ['—'] * 5
        lines.append('| ' + ' | '.join([
            result['label'],
            f"{load.get('connectedDevices', '?')} / {load.get('participatingDevices', '?')}",
            str((result.get('options') or {}).get('rows', '?')),
            str(latency['count'] if latency else 0), *values,
            ' / '.join(str(result.get(key)) for key in ['correct', 'keptUp', 'observationsComplete']),
        ]) + ' |')

    lines.extend([
        '', 'Identical observations present in more than one source are included once. Conflicting '
        'observations with the same label are rejected. Separate repeated runs retain their own labels; '
        'a failed matching repetition remains disqualifying in sizing selection.', '',
        'Deployment restoration flags are historical source snapshots. They do not certify the '
        'current deployment; the final campaign restoration audit remains authoritative.', '',
    ])
    output.mkdir(parents=True, exist_ok=True)
    save(output / 'manifest.json', manifest)
    save(output / 'results.json', list(results.values()))
    save(output / 'sources.json', sources)
    save(output / 'skipped-cases.json', skipped)
    (output / 'README.md').write_text('\n'.join(lines))
    guidance.render(output)
    if caveat:
        path = output / 'SIZING.md'
        title, body = path.read_text().split('\n\n', 1)
        path.write_text(title + '\n\n' + caveat + '\n\n' + body)
    return {'reports': len(reports), 'uniqueRuns': len(results), 'selectedClient': client_sha}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reports', nargs='+', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--client-sha256')
    args = parser.parse_args()
    print(json.dumps(merge(args.reports, args.output, args.client_sha)))


if __name__ == '__main__':
    main()
