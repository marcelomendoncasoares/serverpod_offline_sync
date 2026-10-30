"""Render separately measured cold admission and compression controls."""

import argparse
import json
from pathlib import Path

from idle_capacity_report import NAMES, number


def read(path):
    return json.loads(path.read_text())


def memory(boundaries, phase, key='cgroupMemoryBytes'):
    value = boundaries.get(phase, {}).get(key)
    return number(None if value is None else value / 1024**2)


def render(directory):
    directory = Path(directory)
    rows = {row['label']: row for row in read(directory / 'results.json')}
    profiles = {row['case']: row for row in read(directory / 'resource-boundaries.json')}
    admissions = read(directory / 'admission-controls.json')
    controls = read(directory / 'compression-controls.json')
    manifest = read(directory / 'manifest.json')
    lines = [
        '# Fresh-instance admission and WebSocket compression controls', '',
        'These follow the [five-tier ordinary Serverpod stream sweep]'
        '(../serverpod-idle-capacity-combined-2026-10-30/README.md). The server '
        'executable and SQL-free authenticated echo endpoint are unchanged. '
        'Each case starts on a fresh instance. A diagnostic connector uses '
        "Serverpod's existing method-stream manager and records the actual HTTP "
        'upgrade response, negotiated compression and WebSocket close code.', '',
        '## Cold admission confirmations', '',
        'XL and XXL retry the previously unsuccessful 4,096-connection count '
        'with 32 simultaneous opens instead of 64. This changes both admission '
        'rate and process history, so it is a confirmation under different '
        'conditions, not an isolated measurement of either variable. Successful '
        'upgrades must report HTTP 101 and negotiated permessage-deflate. The '
        'planned idle interval is five minutes; a setup failure never reaches it.', '',
        '| Tier | Target | Successful warmups | Resumed | Verdict / phase | Peak cgroup MiB | Peak server FDs | Restart |',
        '|---|---:|---:|---:|---|---:|---:|---|',
    ]

    for control in admissions:
        row = rows[control['label']]
        verdict = 'PASS' if row['passed'] else 'FAIL / ' + str(row['failurePhase'])
        lines.append(f"| {NAMES[row['size']]} | {row['connections']:,} | {row['opened']:,} | "
                     f"{row['resumed']:,} | {verdict} | {number(row['peakCgroupBytes'] / 1024**2)} | "
                     f"{number(row.get('peakServerFileDescriptors'), 0)} | "
                     f"{'Yes' if row['serverInstanceChanged'] else 'No'} |")

    lines += ['',
        'Successful warmups during an aborted case are not a count of '
        'simultaneously resident sockets. No retry or reconnect is permitted. '
        'Any unexpected fault fails the case; other workers may still finish '
        'opening work before shutdown. Subsequent error, EOF and cleanup '
        'records are not independent connection failures.', '',
    ]
    for control in admissions:
        failures = control['firstTransportFailures']
        first = failures[0]['error'] if failures else 'None'
        statuses = ', '.join(map(str, control['nonUpgradeHttpStatuses'])) or 'none captured'
        codes = ', '.join(map(str, control['webSocketCloseCodes'])) or 'none captured'
        lines.append(f"- {NAMES[control['size']]}: first fault `{first}`. "
                     f'Non-101 HTTP statuses: {statuses}. WebSocket close codes: {codes}.')

    failed_openings = [rows[c['label']] for c in admissions
                       if not c['passed'] and rows[c['label']]['failurePhase'] == 'open']
    if failed_openings:
        lines += ['',
            'These failed openings never reached the planned idle interval. '
            'A timeout without an HTTP response or WebSocket close code does '
            'not locate the fault within the client, network, Cloud ingress or '
            'server. Memory and restart observations are recorded above; '
            'a hardware or framework connection ceiling has not been isolated.',
            '', 'The process file-descriptor limit was not collected. Peaks '
            'near 4,096 descriptors make that limit worth checking, alongside '
            'Cloud ingress and the generator network path, but do not prove '
            'descriptor exhaustion. Earlier sweep failures also occurred '
            'with fewer descriptors. Worker descriptor peaks are retained '
            'in results.json.',
        ]

    lines += ['', '## Compression comparison on Small', '',
        'The first two cases use 256 connections, eight simultaneous opens, '
        '45 seconds idle, eight simultaneous resume probes and 64 closes. '
        'Each starts on a fresh Small instance. The third case attempts '
        '2,048 uncompressed connections for five minutes only after the '
        '256-connection uncompressed case passes. TLS and the streaming '
        'protocol are unchanged.', '',
        '| Compression | Connections | Idle s | Verdict / phase | Before MiB | Open MiB | After idle MiB | After close MiB | Peak MiB |',
        '|---|---:|---:|---|---:|---:|---:|---:|---:|',
    ]
    for control in controls:
        row = rows[control['label']]
        boundaries = profiles[row['label']]['boundaries']
        verdict = 'PASS' if row['passed'] else 'FAIL / ' + str(row['failurePhase'])
        lines.append(f"| {control['mode']} | {row['connections']:,} | {row['idleSeconds']} | {verdict} | "
                     + ' | '.join(memory(boundaries, phase) for phase in ['before', 'open', 'idle', 'close'])
                     + f" | {number(row['peakCgroupBytes'] / 1024**2)} |")

    for control in controls:
        if control['passed']:
            continue
        first = control['firstTransportFailures'][0]
        lines += ['',
            f"The {control['connections']:,}-connection {control['mode']} "
            f"case failed with `{first['error']}`. The first recorded socket "
            f"close code was `{first.get('webSocketCloseCode')}` and its "
            f"upgrade status was `{first.get('upgradeHttpStatus')}`. "
            'This case does not establish a successful idle capacity, '
            'regardless of how many opening receipts were recorded.',
        ]

    paired = {c['mode']: rows[c['label']] for c in controls if c['connections'] == 256}
    if set(paired) == {'enabled', 'disabled'} and all(row['passed'] for row in paired.values()):
        values = {mode: profiles[row['label']]['boundaries']['open']['cgroupMemoryBytes']
                  for mode, row in paired.items()}
        reduction = (1 - values['disabled'] / values['enabled']) * 100
        lines += ['',
            f"At the completed-open boundary, container memory fell from "
            f"{values['enabled'] / 1024**2:.1f} to {values['disabled'] / 1024**2:.1f} MiB "
            f'({reduction:.1f}% lower). Later allocations and collection affect '
            'the idle and full-case peaks; this is a whole-container comparison '
            'rather than a per-connection heap measurement.',
        ]

    lines += ['',
        'Memory in this table is the visible container cgroup measurement, in '
        'MiB. Process RSS and file descriptors are retained in '
        '[resource-boundaries.json](resource-boundaries.json). Missing '
        'boundaries mean the phase did not finish. A high value after close '
        'does not distinguish garbage collection, allocator retention or a leak.', '',
        '| Case | Echoes | Min ms | Median ms | Mean ms | p95 ms | Max ms | Idle CPU cores |',
        '|---|---:|---:|---:|---:|---:|---:|---:|',
    ]
    for control in admissions + controls:
        row = rows[control['label']]
        latency = row.get('probeLatency')
        if not latency:
            continue
        idle = profiles[row['label']]['idleInterval'] or {}
        lines.append(f"| {row['label']} | {latency['count']:,} | "
                     + ' | '.join(number(latency[key]) for key in ['minMs', 'medianMs', 'meanMs', 'p95Ms', 'maxMs'])
                     + f" | {number(idle.get('cpuCoresAverage'), 3)} |")

    lines += ['',
        'Echo timings include the client-to-Cloud network path. Probing eight '
        'connections at a time checks every surviving original stream, but '
        'does not simulate thousands of active requests at once.', '',
        'Disabling compression can save per-socket memory at the cost of '
        'additional wire bytes for compressible active payloads. These echo '
        'controls do not quantify that traffic tradeoff for actual sync data. '
        'This is a diagnostic configuration, not an adopted production change.', '',
        '## Reproduction and evidence', '',
        '- [admission-controls.json](admission-controls.json) and '
        '[compression-controls.json](compression-controls.json) record '
        'handshake checks and the first transport failures.',
        '- [results.json](results.json) preserves complete verdicts, failure '
        'phases, resource peaks, build identities and generator checks.',
        '- [samples.jsonl](samples.jsonl) preserves every successful opening '
        'and echo receipt. [MEASUREMENT_AUDIT.json](MEASUREMENT_AUDIT.json) independently checks '
        'those measurements and exact stream identities.',
        '- [manifest.json](manifest.json) names the distinct server/client '
        'revisions and executable hashes. See the '
        '[replay instructions](../../tool/IDLE_STREAM_CAPACITY.md).', '',
        ('Restoration remains outstanding.' if manifest['restorationRequired'] else
         'The runner verified restoration of the original Small deployment. '
         'See [RESTORATION.json](RESTORATION.json).'), '',
    ]
    (directory / 'README.md').write_text('\n'.join(lines))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report')
    render(parser.parse_args().report)
