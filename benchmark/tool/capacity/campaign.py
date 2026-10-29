import argparse
import datetime
import fcntl
import json
import statistics
import subprocess
import sys
from pathlib import Path

from settings import CONFIG, ROOT, require, sha256


def read(path):
    return json.loads(Path(path).read_text())


def distribution(values):
    if not values:
        return None
    values = sorted(values)
    return {
        'count': len(values),
        'minMs': values[0] / 1000,
        'medianMs': statistics.median(values) / 1000,
        'meanMs': statistics.mean(values) / 1000,
        'p95Ms': values[(len(values) * 95 + 99) // 100 - 1] / 1000,
        'maxMs': values[-1] / 1000,
    }


def assess(label):
    receipt = read(ROOT / (label + '.json'))
    require('exitCode' in receipt, 'Run is incomplete; inspect its tracked process before restarting')
    output = Path(receipt['output'])
    summary = read(output / 'summary.json') if (output / 'summary.json').exists() else {}
    events = [json.loads(line) for line in (output / 'events.jsonl').read_text().splitlines()] if (output / 'events.jsonl').exists() else []
    rounds = [e for e in events if e.get('type') == 'round']
    exercise = [e for e in rounds if e.get('phase') == 'exercise' and e.get('ok')]
    probes = [e for e in rounds if e.get('phase') == 'probe' and e.get('ok')]
    collector = receipt.get('collector', {})
    observed = not collector.get('gaps') and not collector.get('errors') and collector.get('stopped') and collector.get('finalTraces', 0) == collector.get('expectedFinalTraces', 0)
    monitor = receipt.get('generatorMonitoring', {})
    clean = receipt.get('cleanup', {}).get('clean', False)
    correct = summary.get('status') == 'passed' and clean and not monitor.get('guardReason')
    before = read(ROOT / (label + '-before.json'))
    after_path = ROOT / (label + '-after.json')
    after = read(after_path) if after_path.exists() else {}
    resources = read(ROOT / (label + '-resources.json'))
    memory = [r.get('memoryCgroup', {}).get('currentBytes') for r in resources if r.get('memoryCgroup')]
    memory = [m for m in memory if m is not None]
    phase_times = {e['phase']: e['time'] for e in events if e.get('type') == 'phaseStart'}
    phase_ends = {e['phase']: e['time'] for e in events if e.get('type') == 'phaseEnd'}
    server_events = [json.loads(line) for line in Path(receipt['serverEvents']).read_text().splitlines()]
    exercise_start = phase_times.get('exercise')
    exercise_end = phase_times.get('probe')
    observed_exercise = [
        e for e in server_events
        if exercise_start and exercise_end and exercise_start <= e['time'] < exercise_end
    ]
    exercise_process = [e for e in observed_exercise if e.get('type') == 'serverProcess']
    exercise_memory = [e['memoryCgroup']['currentBytes'] for e in exercise_process if e.get('memoryCgroup', {}).get('currentBytes') is not None]
    measured_batches = {
        (e['requestId'], e['batchId'])
        for e in server_events
        if e.get('type') == 'syncFrame' and e.get('direction') == 'received'
        and any(marker['round'] >= 0 for marker in e.get('rounds', []))
    }
    measured_merges = [
        e for e in server_events if e.get('type') == 'mergeTrace'
        and (e['requestId'], e.get('batchId')) in measured_batches
    ]
    merge_transactions = [tx for e in measured_merges for tx in e['transactions']]
    sampled_round_count = sum(e['user'] in receipt.get('sampleUserIndices', []) for e in exercise)
    approximate_cpu = None
    if len(exercise_process) >= 2:
        first, last = exercise_process[0], exercise_process[-1]
        seconds = (datetime.datetime.fromisoformat(last['time']) - datetime.datetime.fromisoformat(first['time'])).total_seconds()
        if seconds > 0:
            approximate_cpu = sum(last['process'][k] - first['process'][k] for k in ['cpuUserTicks', 'cpuSystemTicks']) / 100 / seconds
    result = {
        'label': label,
        'instanceSize': receipt.get('instanceSize', label.split('-')[0]),
        'runId': receipt['runId'],
        'options': summary.get('options'),
        'status': summary.get('status', 'incomplete'),
        'exitCode': receipt['exitCode'],
        'correct': correct,
        'observationsComplete': bool(observed),
        'cleanup': receipt.get('cleanup'),
        'failures': summary.get('failures', []),
        'elapsedSeconds': receipt.get('elapsedSeconds'),
        'phaseStarts': phase_times,
        'phaseSeconds': {
            phase: (datetime.datetime.fromisoformat(phase_ends[phase]) - datetime.datetime.fromisoformat(start)).total_seconds()
            for phase, start in phase_times.items() if phase in phase_ends
        },
        'startedStreamEvents': sum(e.get('type') == 'streamStarted' for e in events),
        'exerciseCompleted': 'exercise' in phase_ends,
        'failurePhase': None if correct else next(reversed(phase_times), 'preflight'),
        'latency': distribution([e['writeToAllPeersMicros'] for e in exercise]),
        'probeLatency': distribution([e['writeToAllPeersMicros'] for e in probes]),
        'scheduleLag': distribution([e['scheduleLagMicros'] for e in exercise]),
        'load': summary.get('load'),
        'concurrency': summary.get('concurrency'),
        'generator': summary.get('generator'),
        'generatorMonitoring': monitor,
        'generatorFileDescriptorLimit': receipt.get('generatorFileDescriptorLimit'),
        'cpuQuota': receipt['cpuQuota'],
        'memoryLimitBytes': before.get('memoryCgroup', {}).get('limitBytes'),
        'peakCgroupBytes': max(memory, default=None),
        'exerciseResources': {
            'sampleCount': len(exercise_process),
            'medianCgroupBytes': statistics.median(exercise_memory) if exercise_memory else None,
            'maxCgroupBytes': max(exercise_memory, default=None),
            'maxLoopLagMs': max((e['loopLag']['maxMicros'] / 1000 for e in exercise_process), default=None),
            'approximateProcessCpuCores': approximate_cpu,
            'scope': 'Server samples selected by client phase wall-clock boundaries; CPU ticks are approximate.',
        },
        'sampledMergeTransactions': {
            'count': len(merge_transactions),
            'receivedRowsAcrossBatches': sum(e['rows'] for e in measured_merges),
            'receivedChangesAcrossBatches': sum(e['changes'] for e in measured_merges),
            'completedSampledRounds': sampled_round_count,
            'transactionsPerCompletedRound': len(merge_transactions) / sampled_round_count if correct and sampled_round_count else None,
            'statementsPerCompletedRound': sum(tx['statements'] for tx in merge_transactions) / sampled_round_count if correct and sampled_round_count else None,
            'sqlWallMsPerCompletedRound': sum(tx['sqlWallMicros'] / 1000 for tx in merge_transactions) / sampled_round_count if correct and sampled_round_count else None,
            'meanStatements': statistics.mean(tx['statements'] for tx in merge_transactions) if merge_transactions else None,
            'meanSqlWallMs': statistics.mean(tx['sqlWallMicros'] / 1000 for tx in merge_transactions) if merge_transactions else None,
            'meanConnectionAndBeginMs': statistics.mean(tx['connectionWaitAndBeginMicros'] / 1000 for tx in merge_transactions) if merge_transactions else None,
            'meanCommitAndReleaseMs': statistics.mean(tx['commitOrRollbackAndReleaseMicros'] / 1000 for tx in merge_transactions) if merge_transactions else None,
            'scope': 'Sampled measured uploads matched by request and batch IDs. SQL wall time includes driver, network, and scheduling.',
        },
        'localCommit': summary.get('localCommit'),
        'observedConnectedDevices': {
            phase: max(e['streams']['open'] for e in events if e.get('type') == 'serverSample' and e['phase'] == phase)
            for phase in ['warmup', 'exercise', 'probe']
            if any(e.get('type') == 'serverSample' and e['phase'] == phase for e in events)
        },
        'databaseBytesBefore': before['storage']['databaseBytes'],
        'databaseBytesAfter': after.get('storage', {}).get('databaseBytes'),
        'serverExecutableSha256': before['server']['executable']['executableSha256'],
        'clientSha256': receipt['clientSha256'],
        'collectorVersion': receipt.get('collectorVersion', 1),
        'schema': before['server']['benchmarkSchema'],
        'rounds': summary.get('rounds'),
        'verifiedUsers': summary.get('verifiedUsers'),
        'unexpectedStreamEnds': summary.get('unexpectedStreamEnds'),
        'recoveryVerifiedLater': (ROOT / (label + '-recovery.json')).exists(),
    }
    result['keptUp'] = result['load'].get('keptUp') if result['load'] and result['load'].get('exerciseMicros') else None
    result['meanBelow1s'] = correct and result['latency'] is not None and result['latency']['meanMs'] < 1000
    result['p95Below1s'] = correct and result['latency'] is not None and result['latency']['p95Ms'] < 1000
    result['p95Below2s'] = correct and result['latency'] is not None and result['latency']['p95Ms'] < 2000
    (ROOT / (label + '-assessment.json')).write_text(json.dumps(result, indent=2) + '\n')
    state = read(ROOT / 'campaign-state.json')
    if label not in state['runs']:
        state['runs'].append(label)
        (ROOT / 'campaign-state.json').write_text(json.dumps(state, indent=2) + '\n')
    return result


def concise(result):
    return {k: result.get(k) for k in ['label', 'status', 'correct', 'observationsComplete', 'keptUp', 'latency', 'probeLatency', 'peakCgroupBytes', 'cleanup', 'failures']}


def run_case(label, **parameters):
    state = read(ROOT / 'campaign-state.json')
    arguments = {
        'quota': state['currentQuota'], 'schema': state['currentSchema'],
        'users': 4, 'active-users': 4, 'devices': 2, 'workers': 8,
        'warmup-workers': 1 if state['currentSize'] == 'small' else 4,
        'rows': 1, 'rounds': 10, 'period': 2000,
        'idle-seconds': 45, 'settle-seconds': 5,
        'payload-bytes': 128,
        'timeout': 30, 'sample': 30,
        'startup': 1200, 'deadline': 3600, 'workload': 'person',
        'schedule': 'spread', 'setup': 1, 'write-mode': 'insert',
        'mode': 'continuous', 'profile': True,
        **{k.replace('_', '-'): v for k, v in parameters.items()},
    }
    require(arguments['schema'] == state['currentSchema'], 'Transition to the case schema before running it.')
    expected = {key.replace('-', '_'): value for key, value in arguments.items()}
    expected.update({'action': 'run', 'label': label, 'client_profile_user': arguments.get('client-profile-user')})

    if (ROOT / (label + '.json')).exists():
        receipt = read(ROOT / (label + '.json'))
        require(receipt['parameters'] == expected, 'Resume refused: the workload changed for ' + label)
        require(receipt['clientSha256'] == CONFIG['clientSha256'] == sha256(CONFIG['client']), 'Resume refused: the client build changed.')
        require(receipt['serverBefore']['executable']['executableSha256'] == state['nativeExecutableSha256'], 'Resume refused: the server build changed.')
        require(receipt['instanceSize'] == state['currentSize'], 'Resume refused: the instance size changed.')
        result = assess(label)
    else:
        command = [sys.executable, str(Path(__file__).with_name('cloud.py')), 'run', label]
        for key, value in arguments.items():
            if isinstance(value, bool):
                if value:
                    command += ['--' + key]
            else:
                command += ['--' + key, str(value)]
        print(json.dumps({'starting': label, 'parameters': arguments}), flush=True)
        with (ROOT / (label + '-launcher.log')).open('w') as stream:
            subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
        result = assess(label)

    print(json.dumps(concise(result)), flush=True)
    if not (result.get('cleanup') or {}).get('clean'):
        from recover import ensure_recovered
        ensure_recovered(label)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['assess', 'idle-sweep', 'file'])
    parser.add_argument('argument', nargs='?')
    args = parser.parse_args()
    with (ROOT / 'campaign.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'assess':
            print(json.dumps(concise(assess(args.argument))), flush=True)
        elif args.action == 'file':
            for case in read(args.argument):
                run_case(**case)
        else:
            state = read(ROOT / 'campaign-state.json')
            require(state['currentSize'] == 'small' and state['currentSchema'] == 'full', "Campaign verification failed: state['currentSize'] == 'small' and state['currentSchema'] == 'full'")
            for connected in [16, 64, 256, 1024, 4096]:
                result = run_case(
                    f'small-full-idle-c{connected}', users=connected // 2,
                    active_users=0, rounds=1,
                )
                if not result['correct'] or not result['observationsComplete']:
                    break
