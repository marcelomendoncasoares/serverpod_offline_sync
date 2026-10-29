from settings import CONFIG, database, require
from compute import read_compute, resize

import argparse
import datetime
import fcntl
import json
import os
import subprocess
import time

from campaign import ROOT, read
from cloud import CLI, clean, control, save


def transition(size, schema):
    state = read(ROOT / 'campaign-state.json')
    before = control('metrics', exact=True)
    require(clean(before), 'A benchmark is still connected or a transaction has not drained')
    require(before['server']['executable']['executableSha256'] == state['nativeExecutableSha256'], "Campaign verification failed: before['server']['executable']['executableSha256'] == state['nativeExecutableSha256']")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    label = f'transition-{size}-{schema}-{stamp}'
    receipt = {'before': before, 'size': size, 'schema': schema}
    save(label + '.json', receipt)

    compute = read_compute()
    require(compute['size'] == state['currentSize'], "Campaign verification failed: compute['size'] == state['currentSize']")
    if size != compute['size']:
        print('Changing compute to ' + size, flush=True)
        compute = resize(size, compute['size'], ROOT / (label + '-compute.json'))

    schema_changed = schema != state['currentSchema'] or before['server']['benchmarkDatabase'] != database(schema)
    if schema_changed:
        environment = {**os.environ, 'CI': 'true', 'DART_SUPPRESS_ANALYTICS': 'true'}
        base = [CLI, '--no-auto-cli-upgrade', '--non-interactive', '--yes',
                '--project-dir', CONFIG['projectDirectory']]
        with (ROOT / (label + '-deploy.log')).open('w') as log:
            for name, value in {
                'BENCHMARK_SCHEMA': schema,
                'BENCHMARK_DATABASE': database(schema),
            }.items():
                subprocess.run(base + ['variable', 'set', '--name', name, '--value', value],
                               env=environment, check=True, stdout=log, stderr=subprocess.STDOUT)
            print('Redeploying the same executable with schema ' + schema, flush=True)
            subprocess.run(base + ['deploy', '--redeploy', '--no-await'],
                           env=environment, check=True, stdout=log, stderr=subprocess.STDOUT)

    changed = size != state['currentSize'] or schema_changed
    deadline = time.monotonic() + 900
    errors = []
    while True:
        try:
            metrics = control('metrics', exact=True)
            server = metrics['server']
            require(server['executable']['executableSha256'] == state['nativeExecutableSha256'], "Campaign verification failed: server['executable']['executableSha256'] == state['nativeExecutableSha256']")
            require(server['benchmarkSchema'] == schema, "Campaign verification failed: server['benchmarkSchema'] == schema")
            require(server['benchmarkDatabase'] == database(schema), "Campaign verification failed: server['benchmarkDatabase'] == database(schema)")
            require(metrics['memoryCgroup']['limitBytes'] == compute['memoryMb'] * 1024**2, "Campaign verification failed: metrics['memoryCgroup']['limitBytes'] == compute['memoryMb'] * 1024**2")
            require(not changed or server['instanceId'] != before['server']['instanceId'], "Campaign verification failed: not changed or server['instanceId'] != before['server']['instanceId']")
            require(clean(metrics), 'Campaign verification failed: clean(metrics)')
            require(server['maxConnectionCount'] == 100, "Campaign verification failed: server['maxConnectionCount'] == 100")
            require(not server['sessionLogging']['persistentEnabled'], "Campaign verification failed: not server['sessionLogging']['persistentEnabled']")
            require(not server['sessionLogging']['consoleEnabled'], "Campaign verification failed: not server['sessionLogging']['consoleEnabled']")
            require(not metrics['commitHints']['enabled'], "Campaign verification failed: not metrics['commitHints']['enabled']")
            receipt['after'] = metrics
            receipt['readinessErrors'] = errors
            save(label + '.json', receipt)
            state.update({
                'currentSize': size,
                'currentSchema': schema,
                'currentQuota': metrics['cpuCgroup']['quotaCores'],
                'environmentChanged': {
                    'BENCHMARK_SCHEMA': schema,
                    'BENCHMARK_DATABASE': server['benchmarkDatabase'],
                },
                'latestTransition': label,
            })
            save('campaign-state.json', state)
            print(json.dumps({'ready': size, 'schema': schema,
                              'cpuQuota': state['currentQuota'],
                              'memoryBytes': metrics['memoryCgroup']['limitBytes'],
                              'executable': server['executable']['executableSha256']}), flush=True)
            return
        except Exception as error:
            errors.append(str(error))
            if time.monotonic() >= deadline:
                receipt['readinessErrors'] = errors
                save(label + '.json', receipt)
                raise
            time.sleep(5)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('size', choices=['small', 'medium', 'large', 'xlarge', 'xxlarge'])
    parser.add_argument('schema', choices=['full', 'city'])
    args = parser.parse_args()
    with (ROOT / 'campaign.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        transition(args.size, args.schema)
