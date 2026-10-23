"""Measure two continuous devices only after proving distinct server processes.

BENCHMARK_SECRET must be supplied by the caller. Servers must enable the benchmark
commit-hint control. Two targets may be distinct local ports or the same load
balancer URL. Placement rejection exits 2, without measuring any rounds.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import statistics
import subprocess
import threading
import time
import urllib.request
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--target', required=True)
parser.add_argument('--peer-target', required=True)
parser.add_argument('--client', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--label', required=True)
parser.add_argument('--deliver', choices=['on', 'off'], required=True)
parser.add_argument('--rounds', type=int, default=20)
parser.add_argument('--period-ms', type=int, default=1700)
parser.add_argument('--server-sha', required=True)
parser.add_argument('--quota', type=float, required=True)
args = parser.parse_args()
secret = os.environ['BENCHMARK_SECRET']
output = Path(args.output) / args.label
output.mkdir(parents=True, exist_ok=False)
targets = [args.target, args.peer_target]
run_id = f'cross-{args.label}-{uuid.uuid4().hex[:12]}'
user_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f'offline-sync-benchmark/{run_id}/user/0'))
receipt = {
    'runId': run_id, 'label': args.label, 'deliver': args.deliver == 'on',
    'rounds': args.rounds, 'periodMs': args.period_ms,
    'clientSha256': hashlib.sha256(Path(args.client).read_bytes()).hexdigest(),
    'expectedServerSha256': args.server_sha, 'expectedQuotaCores': args.quota,
    'clock': 'CLOCK_MONOTONIC_RAW', 'comparison': 'delivered versus deliberately dropped hints',
}


def save():
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


def control(target, body):
    request = urllib.request.Request(
        target + 'benchmark/control',
        json.dumps({'request': json.dumps(body)}).encode(),
        {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + secret},
    )
    result = json.load(urllib.request.urlopen(request, timeout=45))
    return json.loads(result) if isinstance(result, str) else result


def all_instances(body, identity=lambda r: r['instanceId'], expected=None):
    found = {}
    for attempt in range(60):
        target = targets[attempt % 2]
        result = control(target, body)
        instance = identity(result)
        if expected is not None:
            assert instance in expected, 'A server process changed during the comparison.'
        found[instance] = result
        if len(found) == 2:
            return found
        time.sleep(.08)
    raise RuntimeError('Could not reach two distinct server instances.')


def metrics():
    found = all_instances({'action': 'metrics', 'exact': True}, lambda r: r['server']['diagnosticInstanceId'])
    for row in found.values():
        assert row['server']['executable']['executableSha256'] == args.server_sha
        assert row['cpuCgroup']['quotaCores'] == args.quota
        assert row['streams']['open'] == 0
        assert not any(c['count'] for c in row['storage']['connections']
                       if (c['state'] or '').startswith('idle in transaction'))
        assert row['commitHints']['connected']
    return found


process = None
try:
    receipt['before'] = metrics()
    instances = set(receipt['before'])
    configured = all_instances(
        {'action': 'hintDelivery', 'deliver': args.deliver == 'on'}, expected=instances,
    )
    assert all(r['transport']['deliver'] == (args.deliver == 'on') for r in configured.values())
    # Sampling controls are per instance, so verify their effect through the
    # instance-tagged status after each call. Use one atomic control response.
    sampled = set()
    for attempt in range(60):
        result = control(targets[attempt % 2], {
            'action': 'configureSampling', 'runId': run_id, 'userIds': [user_id],
        })
        sampled.add(result['instanceId'])
        if sampled == instances:
            break
    assert sampled == instances
    pages = all_instances({'action': 'diagnostics', 'tail': True}, expected=instances)
    cursors = {instance: row['latestSequence'] for instance, row in pages.items()}
    config = {'targets': targets, 'runId': run_id, 'dataDir': str(output / 'data'),
              'rounds': args.rounds, 'periodMs': args.period_ms}
    (output / 'client.json').write_text(json.dumps(config, indent=2) + '\n')
    save()
    events = []
    messages = queue.Queue()
    log = (output / 'client.log').open('w')
    event_log = (output / 'events.jsonl').open('w')
    process = subprocess.Popen([args.client, str(output / 'client.json')],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)

    def read_client():
        for line in process.stdout:
            log.write(line)
            log.flush()
            if line.startswith('@benchmark '):
                event = json.loads(line.removeprefix('@benchmark '))
                events.append(event)
                event_log.write(json.dumps(event) + '\n')
                event_log.flush()
                messages.put(event)
        messages.put({'type': 'processEnded'})

    reader = threading.Thread(target=read_client, daemon=True)
    reader.start()
    deadline = time.monotonic() + 180
    while True:
        event = messages.get(timeout=max(.1, deadline - time.monotonic()))
        if event['type'] == 'placementReady':
            break
        if event['type'] in ['fatal', 'processEnded']:
            raise RuntimeError('Client failed before the placement barrier; inspect client.log.')
    placement = all_instances({'action': 'hintStatus'}, expected=instances)
    receipt['placement'] = placement
    assigned = {
        trace['deviceId']: instance
        for instance, row in placement.items()
        for trace in row['active'] if trace['runId'] == run_id
    }
    valid = len(assigned) == 2 and set(assigned.values()) == instances
    receipt['deviceInstances'] = assigned
    receipt['placementEligible'] = valid
    process.stdin.write('exercise\n' if valid else 'abort\n')
    process.stdin.flush()
    code = process.wait(timeout=180)
    reader.join(timeout=10)
    log.close()
    event_log.close()
    assert code == 0, 'Cross-process client failed; inspect client.log.'
    if valid:
        rounds = [e for e in events if e.get('type') == 'round' and e.get('phase') == 'exercise']
        assert len(rounds) == args.rounds
        assert all(r['ok'] and r['retries'] == 0 for r in rounds)
        assert any(e['type'] == 'verified' for e in events)
        values = sorted(r['writeToAllPeersMicros'] / 1000 for r in rounds)
        users = [e for e in events if e['type'] == 'userCompleted']
        assert len(users) == 1
        receipt['results'] = {
            'count': len(values), 'minMs': min(values), 'meanMs': statistics.mean(values),
            'medianMs': statistics.median(values), 'p95Ms': values[math.ceil(.95 * len(values)) - 1],
            'maxMs': max(values), 'exactConvergence': True,
            'offeredRateMet': all(e['elapsedMicros'] <= e['budgetMicros'] for e in users),
            'maxScheduleLagMs': max(r['scheduleLagMicros'] for r in rounds) / 1000,
        }
        assert receipt['results']['offeredRateMet']
    else:
        receipt['outcome'] = 'ineligible placement; no timed rounds'

    # Drain all per-instance diagnostic pages after the timed interval. No
    # observer HTTP traffic competes with the measured continuous rounds.
    done = set()
    gaps = []
    with (output / 'server.jsonl').open('w') as server_log:
        for attempt in range(300):
            page = control(targets[attempt % 2], {'action': 'diagnostics', 'cursors': cursors})
            instance = page['instanceId']
            assert instance in instances
            if page['oldestSequence'] > cursors[instance] + 1:
                gaps.append({'instance': instance, 'after': cursors[instance], 'oldest': page['oldestSequence']})
            for record in page['records']:
                server_log.write(json.dumps(record) + '\n')
            cursors[instance] = page['nextSequence']
            if not page['records']:
                done.add(instance)
            if done == instances:
                break
        else:
            raise RuntimeError('Diagnostic drain did not finish.')
    receipt['diagnosticGaps'] = gaps
    receipt['after'] = metrics()
    assert set(receipt['after']) == instances
    receipt['transportCounters'] = {
        instance: {
            key: receipt['after'][instance]['commitHints'][key] - receipt['before'][instance]['commitHints'][key]
            for key in ['received', 'suppressed', 'droppedRevisions']
        }
        for instance in instances
    }
    if valid:
        assert all(row['received'] > 0 for row in receipt['transportCounters'].values())
        assert all((row['suppressed'] > 0) == (args.deliver == 'off') for row in receipt['transportCounters'].values())
    save()
    print(json.dumps({k: receipt[k] for k in ['label', 'placementEligible', 'transportCounters']} |
                     {'results': receipt.get('results'), 'diagnosticGaps': gaps}), flush=True)
    raise SystemExit(0 if valid else 2)
except Exception as error:
    receipt['error'] = type(error).__name__ + ': ' + str(error)
    save()
    raise
finally:
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
