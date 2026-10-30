"""Measure ordinary Serverpod idle method streams on every Cloud size.

The private config names prepared candidate and restoration projects, immutable
build identities, the shared secret file, and a private evidence directory.
Credentials never appear in command arguments or public reports.
"""

import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import statistics
import subprocess
import sys
import tempfile
import time


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.pending')
    temporary.write_text(json.dumps(data, indent=2) + '\n')
    temporary.replace(path)


def read(path):
    return json.loads(Path(path).read_text())


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def next_lower(passing, failing):
    """One midpoint refinement below the failure, always an even stream count."""
    midpoint = ((passing + failing) // 4) * 2
    return midpoint if passing < midpoint < failing else None


class Campaign:
    def __init__(self, args):
        self.args = args
        self.config = read(args.config)
        self.root = Path(self.config['evidenceDirectory'])
        self.root.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.environ['CAPACITY_CONFIG'] = str(Path(args.config).resolve())
        os.environ['CAPACITY_EVIDENCE'] = str(self.root)
        sys.path.insert(0, str(Path(__file__).parent / 'capacity'))
        from cloud import clean, control
        from compute import read_compute, resize
        from deployment import cli, variables
        from generator_monitor import GeneratorMonitor
        from settings import secret
        self.clean = clean
        self.control = control
        self.compute = read_compute
        self.resize = resize
        self.cli = cli
        self.variables = variables
        self.secret = secret
        self.monitor_class = GeneratorMonitor
        self.state_path = self.root / 'campaign.json'
        self.state = read(self.state_path) if self.state_path.exists() else {
            'startedAt': utc(), 'status': 'prepared', 'cases': [], 'tiers': [],
        }

    def persist(self):
        save(self.state_path, self.state)

    def metrics(self):
        return self.control('metrics', exact=True)

    def check_protected(self, snapshot):
        for path, digest in snapshot['protectedFiles'].items():
            require(sha256(path) == digest, 'Protected configuration changed: ' + path)

    def snapshot(self):
        path = self.root / 'restoration-snapshot.json'
        if path.exists():
            snapshot = read(path)
            self.check_protected(snapshot)
            return snapshot
        metrics = self.metrics()
        require(self.clean(metrics), 'Existing streams or idle transactions before deployment.')
        require(metrics['server']['executable']['executableSha256'] ==
                self.config['originalServerExecutableSha256'], 'Unexpected original server.')
        compute = self.compute()
        require(compute['minInstances'] == compute['maxInstances'] == 1, 'Expected one instance.')
        snapshot = {
            'time': utc(), 'metrics': metrics, 'compute': compute,
            'variables': self.variables(),
            'protectedFiles': {p: sha256(p) for p in self.config['protectedFiles']},
        }
        save(path, snapshot)
        return snapshot

    def set_variables(self, wanted, project):
        current = self.variables()
        for name, value in wanted.items():
            if current[name] == value:
                continue
            command = ['variable', 'unset', '--name', name] if value is None else [
                'variable', 'set', '--name', name, '--value', value,
            ]
            self.cli(command, project_directory=project)

    def wait_ready(self, *, original=False, changed_instance=None):
        snapshot = read(self.root / 'restoration-snapshot.json')
        wanted = snapshot['metrics']['server'] if original else None
        deadline = time.monotonic() + 1200
        errors = []
        while True:
            try:
                metrics = self.metrics()
                server = metrics['server']
                require(self.clean(metrics), 'Streams or transactions remain.')
                require(server['maxConnectionCount'] == 100, 'Pool size changed.')
                require(not server['sessionLogging']['persistentEnabled'] and
                        not server['sessionLogging']['consoleEnabled'], 'Logging must remain disabled.')
                require(not metrics['commitHints']['enabled'], 'Commit hints must remain disabled.')
                if original:
                    require(server['executable']['executableSha256'] ==
                            wanted['executable']['executableSha256'], 'Original executable differs.')
                    for key in ['benchmarkSchema', 'benchmarkDatabase']:
                        require(server[key] == wanted[key], 'Original deployment mismatch: ' + key)
                else:
                    require(server['benchmarkDatabase'] == self.config['databases']['full'],
                            'Candidate database has not deployed.')
                    transport = self.control('transportMetrics')
                    require(transport['transport']['open'] == 0, 'Echo streams have not drained.')
                    expected = (self.state.get('serverExecutableSha256') or
                                self.config.get('serverExecutableSha256'))
                    actual = server['executable']['executableSha256']
                    require(actual != self.config['originalServerExecutableSha256'],
                            'Candidate executable has not deployed.')
                    require(expected is None or expected == actual, 'Candidate executable changed.')
                compute = self.compute()
                require(compute['minInstances'] == compute['maxInstances'] == 1, 'Instance count changed.')
                require(metrics['memoryCgroup']['limitBytes'] == compute['memoryMb'] * 1024**2,
                        'Compute resize has not reached the running instance.')
                require(changed_instance is None or server['instanceId'] != changed_instance,
                        'Waiting for replacement instance.')
                save(self.root / 'readiness.json', {'time': utc(), 'metrics': metrics,
                                                  'compute': compute, 'errors': errors})
                return metrics
            except Exception as error:
                errors.append(str(error))
                if time.monotonic() >= deadline:
                    save(self.root / 'readiness-failure.json', {'errors': errors})
                    raise
                time.sleep(5)

    def deploy(self):
        self.snapshot()
        self.state['restorationRequired'] = True
        self.state['status'] = 'deploying'
        self.persist()
        self.set_variables({'BENCHMARK_SCHEMA': 'full',
                            'BENCHMARK_DATABASE': self.config['databases']['full']},
                           self.config['projectDirectory'])
        current = self.metrics()['server']['executable']['executableSha256']
        expected = (self.state.get('serverExecutableSha256') or
                    self.config.get('serverExecutableSha256'))
        if current != expected:
            require(current == self.config['originalServerExecutableSha256'],
                    'Unrelated executable before candidate deployment.')
            self.cli(['deploy', '--dart-version', '3.13.7', '--no-await', '--output',
                      str(self.root / 'deployment.zip')])
        metrics = self.wait_ready()
        self.state['serverExecutableSha256'] = metrics['server']['executable']['executableSha256']
        self.state['status'] = 'measuring'
        self.persist()

    def transition(self, size):
        before = self.wait_ready()
        compute = self.compute()
        if compute['size'] != size:
            self.resize(size, compute['size'], self.root / f'resize-{size}.json')
            before = self.wait_ready(changed_instance=before['server']['instanceId'])
        print(json.dumps({'ready': size, 'memoryBytes': before['memoryCgroup']['limitBytes'],
                          'visibleCpuQuota': before['cpuCgroup']['quotaCores']}), flush=True)

    def run_case(self, size, connections, idle_seconds, suffix):
        label = f'{size}-echo-c{connections}-idle{idle_seconds}-{suffix}'
        receipt_path = self.root / 'cases' / f'{label}.json'
        workload = {'size': size, 'connections': connections, 'idleSeconds': idle_seconds,
                    'openWorkers': self.config.get('openWorkers', {}).get(size, 1 if size == 'small' else 4),
                    'openConcurrencyPerWorker': self.config.get('openConcurrencyPerWorker', {}).get(size, 1),
                    'workers': 8,
                    'clientSha256': self.config['clientSha256'],
                    'serverExecutableSha256': self.state['serverExecutableSha256']}
        if receipt_path.exists():
            previous = read(receipt_path)
            require(previous['workload'] == workload, 'Recorded case configuration changed.')
            require(previous['status'] == 'completed', 'An incomplete case needs inspection before retry.')
            return previous
        require(sha256(self.config['client']) == workload['clientSha256'], 'Client binary changed.')
        before = self.wait_ready()
        require(self.compute()['size'] == size, 'Wrong tier before measurement.')
        output = self.root / 'runs' / label
        run_id = label + '-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        command = [self.config['client'], '--target', self.config['target'], '--output', str(output),
                   '--run-id', run_id, '--connections', str(connections), '--workers', '8',
                   '--open-workers', str(workload['openWorkers']),
                   '--open-concurrency-per-worker', str(workload['openConcurrencyPerWorker']),
                   '--idle-seconds', str(idle_seconds)]
        receipt = {'label': label, 'workload': workload, 'startedAt': utc(), 'status': 'running',
                   'before': before, 'command': command}
        save(receipt_path, receipt)
        monitor = self.monitor_class()
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        limit = min(max(soft, 65536), hard)
        print(json.dumps({'starting': label}), flush=True)
        try:
            with (self.root / 'cases' / f'{label}.log').open('w') as log:
                process = subprocess.Popen(['prlimit', f'--nofile={limit}:{hard}', '--', *command],
                    env={**os.environ, 'BENCHMARK_SECRET': self.secret()}, start_new_session=True,
                    stdout=log, stderr=subprocess.STDOUT)
                monitor.start(process.pid)
                try:
                    receipt['exitCode'] = process.wait(timeout=7200)
                except BaseException:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    raise
        finally:
            monitor.stop()
            receipt['generator'] = monitor.summary()
            save(self.root / 'cases' / f'{label}-generator.json', monitor.samples)
            receipt['finishedAt'] = utc()
            if (output / 'summary.json').exists():
                receipt['summary'] = read(output / 'summary.json')
            receipt['after'] = self.wait_ready()
            receipt['status'] = 'completed'
            summary = receipt.get('summary', {})
            receipt['passed'] = (receipt.get('exitCode') == 0 and summary.get('status') == 'passed'
                                 and monitor.guard_reason is None and not monitor.errors)
            save(receipt_path, receipt)
            if label not in self.state['cases']:
                self.state['cases'].append(label)
            self.persist()
            self.export()
        print(json.dumps({'completed': label, 'passed': receipt['passed'],
                          'opened': summary.get('opened'), 'resumed': summary.get('resumed'),
                          'failurePhase': summary.get('failurePhase'),
                          'probe': summary.get('probeLatency')}), flush=True)
        return receipt

    def measure(self):
        for size in self.args.sizes:
            self.transition(size)
            passing = 0
            failing = None
            for count in self.args.points:
                result = self.run_case(size, count, 45, 'screen')
                if result['passed']:
                    passing = count
                else:
                    failing = count
                    break
            for _ in range(2):
                if failing is None:
                    break
                count = next_lower(passing, failing)
                if count is not None:
                    result = self.run_case(size, count, 45, 'refinement')
                    if result['passed']:
                        passing = count
                    else:
                        failing = count
            qualified = None
            candidate = passing
            while candidate >= 2:
                result = self.run_case(size, candidate, self.args.qualification_idle_seconds, 'qualification')
                if result['passed']:
                    qualified = candidate
                    break
                candidate = (candidate // 4) * 2
            self.state['tiers'] = [tier for tier in self.state['tiers'] if tier['size'] != size]
            self.state['tiers'].append({'size': size, 'largestShortPass': passing,
                'firstUnsuccessfulTarget': failing, 'longIdleQualified': qualified,
                'ceilingReached': failing is None})
            self.persist()
            self.export()

    def restore(self):
        snapshot = read(self.root / 'restoration-snapshot.json')
        self.check_protected(snapshot)
        before = self.metrics()
        allowed = {self.config['originalServerExecutableSha256'], self.state.get('serverExecutableSha256'),
                   self.config.get('serverExecutableSha256')}
        source = (before['server'].get('preparedSource') or {}).get('sourceRevision')
        require(before['server']['executable']['executableSha256'] in allowed or
                source == self.config['sourceRevision'], 'Unrelated deployment; refusing restoration.')
        require(self.clean(before), 'Streams or transactions have not drained before restoration.')
        if before['server']['executable']['executableSha256'] != self.config['originalServerExecutableSha256']:
            require(self.control('transportMetrics')['transport']['open'] == 0, 'Echo streams remain.')
        current = self.compute()
        wanted = snapshot['compute']
        if current['size'] != wanted['size']:
            self.resize(wanted['size'], current['size'], self.root / 'restoration-compute.json')
        project = self.config['originalProjectDirectory']
        self.set_variables(snapshot['variables'], project)
        self.cli(['deploy', '--dart-version', '3.13.7', '--no-await', '--output',
                  str(self.root / 'restoration-deployment.zip')], project_directory=project)
        after = self.wait_ready(original=True)
        require(self.variables() == snapshot['variables'], 'Variables did not restore.')
        self.check_protected(snapshot)
        save(self.root / 'restoration-receipt.json', {'verifiedAt': utc(), 'verified': True,
            'metrics': after, 'protectedFilesVerified': len(snapshot['protectedFiles'])})
        self.state['restorationRequired'] = False
        self.persist()

    def export(self):
        report = Path(self.config['reportDirectory'])
        report.mkdir(parents=True, exist_ok=True)
        rows = []
        samples = []
        for label in self.state['cases']:
            receipt = read(self.root / 'cases' / f'{label}.json')
            summary = receipt.get('summary', {})
            events_path = self.root / 'runs' / label / 'events.jsonl'
            events = [json.loads(line) for line in events_path.read_text().splitlines()] if events_path.exists() else []
            server_samples = [e for e in events if e['type'] == 'serverSample']
            memory = [e['memoryCgroup'].get('currentBytes') for e in server_samples]
            memory = [v for v in memory if isinstance(v, int)]
            for e in events:
                if e['type'] in ['probe', 'opened', 'workerSample', 'workerIdle']:
                    samples.append({'case': label, **e})
            rows.append({
                'label': label, **receipt['workload'], 'passed': receipt['passed'],
                **{key: summary.get(key) for key in ['failurePhase', 'failures', 'opened', 'resumed',
                    'idleCompleted', 'streamFailures', 'sampleFailures', 'cleanupVerified',
                    'openLatency', 'probeLatency', 'phaseSeconds']},
                'generator': receipt['generator'],
                'peakCgroupBytes': max(memory, default=None),
                'memoryLimitBytes': receipt['before']['memoryCgroup']['limitBytes'],
                'visibleCpuQuota': receipt['before']['cpuCgroup']['quotaCores'],
                'serverOpenAtBoundaries': {phase: value['transport']['open']
                    for phase, value in summary.get('boundaries', {}).items()},
                'serverInstanceChanged': receipt['before']['server']['instanceId'] !=
                    receipt['after']['server']['instanceId'],
            })
        save(report / 'results.json', rows)
        save(report / 'tiers.json', self.state['tiers'])
        with (report / 'samples.jsonl').open('w') as stream:
            for sample in samples:
                stream.write(json.dumps(sample) + '\n')
        save(report / 'manifest.json', {
            'sourceRevision': self.config['sourceRevision'],
            'serverSourceRevision': self.config['sourceRevision'],
            'clientSourceRevision': self.config.get('clientSourceRevision', self.config['sourceRevision']),
            'serverExecutableSha256': self.state.get('serverExecutableSha256'),
            'clientSha256': self.config['clientSha256'],
            'createdAt': utc(), 'restorationRequired': self.state.get('restorationRequired'),
            'sizes': self.args.sizes, 'points': self.args.points,
            'screenIdleSeconds': 45, 'qualificationIdleSeconds': self.args.qualification_idle_seconds,
            'workers': 8, 'probeConcurrency': 8, 'closeConcurrency': 64,
            'openWorkers': self.config.get('openWorkers',
                {'small': 1, 'medium': 4, 'large': 4, 'xlarge': 4, 'xxlarge': 4}),
            'openConcurrencyPerWorker': self.config.get('openConcurrencyPerWorker', {}),
            'authentication': 'Authenticated benchmark admin, no database lookup.',
            'endpoint': 'Ordinary bidirectional Serverpod method stream echoing String messages.',
            'measurement': 'One Client and WebSocket per connection; no Offline Sync session or SQL.',
        })


def main():
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Interrupted by signal {signum}.')

    signal.signal(signal.SIGTERM, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--action', choices=['run', 'restore', 'export'], default='run')
    parser.add_argument('--sizes', nargs='+', default=['small', 'medium', 'large', 'xlarge', 'xxlarge'])
    parser.add_argument('--points', nargs='+', type=int, default=[64, 256, 1024, 4096, 8192, 16384])
    parser.add_argument('--qualification-idle-seconds', type=int, default=300)
    args = parser.parse_args()
    require(args.points == sorted(set(args.points)) and all(n >= 2 for n in args.points),
            'Connection counts must be positive and strictly increasing.')
    campaign = Campaign(args)
    if args.action == 'export':
        campaign.export()
        return
    directory = Path(tempfile.gettempdir()) / f'offline-sync-capacity-locks-{os.getuid()}'
    directory.mkdir(mode=0o700, exist_ok=True)
    name = hashlib.sha256(json.dumps(campaign.config['project'], sort_keys=True,
                                    separators=(',', ':')).encode()).hexdigest()
    with (directory / name).open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'restore':
            campaign.restore()
            campaign.export()
            return
        try:
            campaign.deploy()
            campaign.measure()
            campaign.state['status'] = 'measured'
            campaign.persist()
        finally:
            if campaign.state.get('restorationRequired'):
                campaign.restore()
            campaign.export()


if __name__ == '__main__':
    main()
