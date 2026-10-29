"""Compare the same measured workloads; failed runs do not supply speedup claims."""

import json
from pathlib import Path

from matrix import validate_matrix
from settings import save


def load_report(directory):
    directory = Path(directory)
    manifest = json.loads((directory / 'manifest.json').read_text())
    matrix = json.loads((directory / 'replay.json').read_text())
    validate_matrix(matrix)
    return (
        manifest,
        {case['id']: case for case in matrix['cases']},
        {result['label']: result for result in json.loads((directory / 'results.json').read_text())},
    )


def exact_starting_counts(result):
    if not result:
        return None

    context = result.get('interpretation', {}).get('datasetContext', {})
    counts = context.get('domainRowsBefore')
    if context.get('tableCountsExactBefore') is not True or not counts:
        return None

    return counts


def compare(baseline, candidate, output):
    old_manifest, old_cases, old_results = load_report(baseline)
    new_manifest, new_cases, new_results = load_report(candidate)
    rows = []
    settings = ['databasePoolLimit', 'mergeConcurrencyLimit', 'commitHints',
                'persistentSessionLogging', 'consoleSessionLogging', 'databasePlacement']
    differences = [key for key in settings if old_manifest.get(key) != new_manifest.get(key)]

    for case_id in dict.fromkeys([*old_cases, *new_cases]):
        old_case, new_case = old_cases.get(case_id), new_cases.get(case_id)
        old, new = old_results.get(case_id), new_results.get(case_id)
        matched = bool(old_case and new_case and old_case['caseSha256'] == new_case['caseSha256'])
        same_resources = bool(old and new and all(old.get(key) == new.get(key) for key in ['cpuQuota', 'memoryLimitBytes']))
        same_collector = bool(old and new and old.get('collectorVersion', 1) == new.get('collectorVersion', 1))
        old_counts, new_counts = exact_starting_counts(old), exact_starting_counts(new)
        same_counts = old_counts == new_counts if old_counts is not None and new_counts is not None else None
        valid = bool(matched and same_resources and same_collector and same_counts is True
                     and not differences and old and new
                     and old['correct'] and new['correct']
                     and old['observationsComplete'] and new['observationsComplete'])
        row = {
            'case': case_id, 'matchingWorkload': matched,
            'matchingResources': same_resources, 'comparableLatency': valid,
            'matchingCollector': same_collector,
            'matchingStartingDomainCounts': same_counts,
            'baselineStartingDomainCounts': old_counts,
            'candidateStartingDomainCounts': new_counts,
            'baselineCorrect': old.get('correct') if old else None,
            'candidateCorrect': new.get('correct') if new else None,
            'baselineKeptUp': old.get('keptUp') if old else None,
            'candidateKeptUp': new.get('keptUp') if new else None,
            'baselineLatency': old.get('latency') if old else None,
            'candidateLatency': new.get('latency') if new else None,
            'reductionsPercent': None,
        }
        if valid and row['baselineLatency'] and row['candidateLatency']:
            row['reductionsPercent'] = {
                key: 100 * (old['latency'][key] - new['latency'][key]) / old['latency'][key]
                for key in ['medianMs', 'meanMs', 'p95Ms'] if old['latency'][key] > 0
            }
        rows.append(row)

    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    value = {
        'baselineServerSha256': old_manifest['serverExecutableSha256'],
        'candidateServerSha256': new_manifest['serverExecutableSha256'],
        'configurationDifferences': differences, 'cases': rows,
    }
    save(output / 'comparison.json', value)
    document = [
        '# Capacity comparison', '',
        'Positive percentages mean lower latency. Reductions are shown only for matching workloads, '
        'resources, configuration, and exact starting domain-table counts where both runs converged '
        'with complete observations. Missing or unequal starting counts suppress percentage comparisons. '
        'Equal counts do not establish identical physical database state or eliminate run-to-run variation. '
        'Failures retain their verdicts; incomplete timings do not establish a speedup.', '',
        '| Case | Correct before / after | Kept up before / after | Starting counts match | Median reduction | Mean reduction | p95 reduction |',
        '|---|---|---|---|---:|---:|---:|',
    ]
    for row in rows:
        reductions = row['reductionsPercent'] or {}
        values = [f'{reductions[key]:.1f}%' if key in reductions else '—'
                  for key in ['medianMs', 'meanMs', 'p95Ms']]
        document.append('| ' + ' | '.join([
            row['case'], f"{row['baselineCorrect']} / {row['candidateCorrect']}",
            f"{row['baselineKeptUp']} / {row['candidateKeptUp']}",
            str(row['matchingStartingDomainCounts']), *values,
        ]) + ' |')
    (output / 'README.md').write_text('\n'.join(document) + '\n')
    return value

