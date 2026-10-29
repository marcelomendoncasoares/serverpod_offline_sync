import argparse
import datetime
import hashlib
import json
import math
import os
import resource
import statistics
import signal
import subprocess
import threading
import time
import urllib.request
import uuid
from pathlib import Path

from generator_monitor import GeneratorMonitor
from settings import ROOT, CONFIG, database, require, secret, sha256

CLI = CONFIG.get('scloud', 'scloud')
TARGET = CONFIG.get('target', '').rstrip('/') + '/'
CLIENT = Path(CONFIG.get('client', 'rounds')).expanduser()


def save(name, data):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def control(action, **body):
    request = urllib.request.Request(
        TARGET + 'benchmark/control',
        json.dumps({'request': json.dumps({'action': action, **body})}).encode(),
        {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + secret()},
    )
    result = json.load(urllib.request.urlopen(request, timeout=60))
    return json.loads(result) if isinstance(result, str) else result


def distribution(values):
    values = sorted(values)
    return None if not values else {
        'n': len(values), 'min': values[0], 'median': statistics.median(values),
        'mean': statistics.mean(values), 'p95': values[math.ceil(len(values) * .95) - 1],
        'max': values[-1],
    }


def clean(metrics):
    return metrics['streams']['open'] == 0 and not any(
        row['count'] for row in metrics['storage']['connections']
        if (row['state'] or '').startswith('idle in transaction'))


def run(args):
    campaign = json.loads((ROOT / 'campaign-state.json').read_text())
    require(not campaign.get('pauseNewRuns'), 'New cases paused for benchmark-client scheduling correction')
    before = control('metrics', exact=True)
    identity = before['server']
    require(clean(before), 'Prior run has not drained')
    state = json.loads((ROOT / 'campaign-state.json').read_text())
    require(identity['executable']['executableSha256'] == state['nativeExecutableSha256'], "Campaign verification failed: identity['executable']['executableSha256'] == state['nativeExecutableSha256']")
    require(identity['benchmarkSchema'] == args.schema, "Campaign verification failed: identity['benchmarkSchema'] == args.schema")
    require(identity['benchmarkDatabase'] == database(args.schema), "Campaign verification failed: identity['benchmarkDatabase'] == database(args.schema)")
    require(before['server']['maxConnectionCount'] == 100, "Campaign verification failed: before['server']['maxConnectionCount'] == 100")
    require(not before['server']['sessionLogging']['persistentEnabled'], "Campaign verification failed: not before['server']['sessionLogging']['persistentEnabled']")
    require(not before['server']['sessionLogging']['consoleEnabled'], "Campaign verification failed: not before['server']['sessionLogging']['consoleEnabled']")
    require(not before['commitHints']['enabled'], "Campaign verification failed: not before['commitHints']['enabled']")
    require(before['cpuCgroup']['quotaCores'] == args.quota, "Campaign verification failed: before['cpuCgroup']['quotaCores'] == args.quota")
    require(sha256(CLIENT) == CONFIG['clientSha256'], 'The client binary changed during this campaign.')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run_id = f'capacity-{args.label}-{stamp}'
    output = ROOT / 'runs' / run_id
    require(not (ROOT / (args.label + '.json')).exists(), 'Use a unique label')
    selected = [0] if args.profile else []
    users = [str(uuid.uuid5(uuid.NAMESPACE_URL, f'offline-sync-benchmark/{run_id}/user/{user}')) for user in selected]
    sampling_receipt = control('configureSampling', runId=run_id, userIds=users, wireProfile=False, nativeHeartbeat=True, nativeCpuProfile=False)
    tail = control('diagnostics', tail=True)
    state = {'instance': tail['instanceId'], 'cursor': tail['latestSequence'], 'records': 0, 'gaps': [], 'errors': []}
    stop = threading.Event()
    resources = []
    events_path = ROOT / (args.label + '-server.jsonl')

    def collect():
        with events_path.open('w') as stream:
            while True:
                page = None
                try:
                    page = control('diagnostics', cursors={state['instance']: state['cursor']})
                    require(page['instanceId'] == state['instance'], 'Diagnostic instance changed')
                    if page['oldestSequence'] > state['cursor'] + 1:
                        state['gaps'].append({'after': state['cursor'], 'oldest': page['oldestSequence']})
                    for record in page['records']:
                        stream.write(json.dumps(record) + '\n')
                        if record.get('type') == 'serverProcess':
                            resources.append({
                                'process': record['process'],
                                'cpuCgroup': record['cpuCgroup'],
                                'sampleTime': record['time'],
                                'clientReceivedTime': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                                'memoryCgroup': record.get('memoryCgroup'),
                                'loopLag': record.get('loopLag'),
                            })
                    stream.flush()
                    state['records'] += len(page['records'])
                    state['cursor'] = page['nextSequence']
                except Exception as error:
                    state['errors'].append(str(error))
                    page = None
                if stop.is_set():
                    return
                if page is not None and state['cursor'] < page['latestSequence']:
                    continue
                stop.wait(2)

    command = [str(CLIENT), '--target', TARGET, '--run-id', run_id, '--data-dir', str(output.parent),
               '--users', str(args.users), '--devices', str(args.devices), '--workers', str(min(args.users, args.workers)),
               '--active-users', str(args.active_users if args.active_users is not None else args.users),
               '--schedule', args.schedule, '--warmup-workers', str(args.warmup_workers),
               '--idle-seconds', str(args.idle_seconds), '--settle-seconds', str(args.settle_seconds),
               '--rounds', str(args.rounds), '--rows', str(args.rows), '--period-ms', str(args.period),
               '--payload-bytes', str(args.payload_bytes),
               '--sample-seconds', str(args.sample), '--timeout-seconds', str(args.timeout),
               '--startup-timeout-seconds', str(args.startup), '--setup-concurrency', str(args.setup),
               '--schema', args.schema, '--workload', args.workload, '--write-mode', args.write_mode,
               '--mode', args.mode, '--no-sync-diagnostics']
    if args.client_profile_user is not None:
        command += ['--client-profile-user', str(args.client_profile_user)]

    receipt = {'instanceSize': campaign['currentSize'], 'parameters': vars(args), 'samplingConfiguration': sampling_receipt, 'label': args.label, 'runId': run_id, 'command': command, 'output': str(output),
               'serverBefore': before['server'], 'cpuQuota': args.quota,
               'clientSha256': hashlib.sha256(CLIENT.read_bytes()).hexdigest(),
               'collectorVersion': 2,
               'wireProfile': False, 'sampleUserIndices': selected, 'sampleUserIds': users,
               'serverEvents': str(events_path)}
    soft_fds, hard_fds = resource.getrlimit(resource.RLIMIT_NOFILE)
    client_fds = min(max(soft_fds, 65536), hard_fds)
    receipt['generatorFileDescriptorLimit'] = {'soft': client_fds, 'hard': hard_fds}
    save(args.label + '-before.json', before)
    save(args.label + '.json', receipt)
    collector = threading.Thread(target=collect, daemon=True)
    collector.start()
    generator_monitor = GeneratorMonitor()
    started = time.clock_gettime(time.CLOCK_MONOTONIC_RAW)
    print(json.dumps({'started': args.label, 'command': command}), flush=True)
    try:
        with (ROOT / (args.label + '.log')).open('w') as log:
            process = subprocess.Popen(
                ['prlimit', f'--nofile={client_fds}:{hard_fds}', '--', *command],
                env={**os.environ, 'BENCHMARK_SECRET': secret()},
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            generator_monitor.start(process.pid)
            try:
                receipt['exitCode'] = process.wait(timeout=args.deadline)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)
                receipt['exitCode'] = 'deadline'
            except BaseException:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)
                receipt['exitCode'] = 'interrupted'
                raise
    finally:
        generator_monitor.stop()
        receipt['generatorMonitoring'] = generator_monitor.summary()
        save(args.label + '-generator.json', generator_monitor.samples)
        stop.set()
        collector.join(timeout=65)
        receipt['elapsedSeconds'] = time.clock_gettime(time.CLOCK_MONOTONIC_RAW) - started
        receipt['collector'] = {**state, 'stopped': not collector.is_alive()}
        save(args.label + '-resources.json', resources)
        try:
            after = control('metrics', exact=False)
            save(args.label + '-after.json', after)
            receipt['cleanup'] = {'clean': clean(after), 'streams': after['streams']['open']}
            # Stream teardown can emit its final trace after the client's
            # process exits. Drain once cleanup is known, without adding any
            # observation work to the measured exercise window.
            if not collector.is_alive():
                expected_traces = args.devices * len(selected) if args.mode == 'continuous' else 0
                trace_ids = {
                    record['requestId']
                    for line in events_path.read_text().splitlines()
                    if (record := json.loads(line)).get('type') == 'syncTrace'
                    and record.get('runId') == run_id
                }
                trace_deadline = time.monotonic() + 10
                with events_path.open('a') as stream:
                    for _ in range(1024):
                        page = control('diagnostics', cursors={state['instance']: state['cursor']})
                        require(page['instanceId'] == state['instance'], 'Diagnostic instance changed')
                        if page['oldestSequence'] > state['cursor'] + 1:
                            state['gaps'].append({'after': state['cursor'], 'oldest': page['oldestSequence']})
                        for record in page['records']:
                            stream.write(json.dumps(record) + '\n')
                            if record.get('type') == 'syncTrace' and record.get('runId') == run_id:
                                trace_ids.add(record['requestId'])
                        state['records'] += len(page['records'])
                        state['cursor'] = page['nextSequence']
                        if state['cursor'] >= page['latestSequence']:
                            if len(trace_ids) >= expected_traces or time.monotonic() >= trace_deadline:
                                break
                            time.sleep(0.25)
                receipt['collector'] = {**state, 'stopped': True}
                receipt['collector']['finalTraces'] = len(trace_ids)
                receipt['collector']['expectedFinalTraces'] = expected_traces
            if clean(after):
                control('configureSampling', runId='disabled', userIds=[])
        except Exception as error:
            receipt['cleanupError'] = str(error)
        summary = output / 'summary.json'
        if summary.exists():
            data = json.loads(summary.read_text())
            receipt.update({k: data[k] for k in ['status', 'failures', 'writeToAllPeers', 'load', 'rounds', 'verifiedUsers', 'unexpectedStreamEnds', 'concurrency', 'generator'] if k in data})
        receipt['resourceSampling'] = {
            'source': 'Existing one-second serverProcess diagnostic records',
            'controlCalls': 'Diagnostics every two seconds, draining queued pages before waiting; no additional runtime or SQL sampling calls',
            'samples': len(resources),
        }
        save(args.label + '.json', receipt)
    print(json.dumps({k: receipt.get(k) for k in ['label', 'status', 'failures', 'elapsedSeconds', 'writeToAllPeers', 'load', 'cleanup']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='action', required=True)
    r = sub.add_parser('run')
    r.add_argument('label')
    for name, default in [('users', 1), ('rounds', 8), ('rows', 1), ('period', 2000), ('sample', 30), ('timeout', 45), ('setup', 1), ('deadline', 1200)]:
        r.add_argument('--' + name, type=int, default=default)
    r.add_argument('--quota', type=float, required=True)
    r.add_argument('--active-users', type=int)
    r.add_argument('--devices', type=int, default=2)
    r.add_argument('--workers', type=int, default=8)
    r.add_argument('--warmup-workers', type=int, default=1)
    r.add_argument('--idle-seconds', type=int, default=60)
    r.add_argument('--settle-seconds', type=int, default=5)
    r.add_argument('--payload-bytes', type=int, default=128)
    r.add_argument('--startup', type=int, default=1200)
    r.add_argument('--schedule', choices=['spread', 'burst'], default='spread')
    r.add_argument('--schema', default='full')
    r.add_argument('--workload', default='person')
    r.add_argument('--write-mode', default='insert')
    r.add_argument('--mode', default='continuous')
    r.add_argument('--profile', action='store_true')
    r.add_argument('--client-profile-user', type=int)
    args = parser.parse_args()
    run(args)
