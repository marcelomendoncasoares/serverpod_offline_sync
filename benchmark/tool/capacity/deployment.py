"""Snapshot and restore the deployment settings owned by a campaign."""

import json
import os
import subprocess
import time
from pathlib import Path

from cloud import clean, control
from compute import read_compute, resize
from settings import CONFIG, ROOT, require, save, sha256


VARIABLES = ['BENCHMARK_SCHEMA', 'BENCHMARK_DATABASE']


def cli(arguments, project_directory=None, capture=False):
    command = [
        CONFIG.get('scloud', 'scloud'), '--no-auto-cli-upgrade',
        '--non-interactive', '--yes', '--format=json', '--project-dir',
        project_directory or CONFIG['projectDirectory'], *arguments,
    ]
    environment = {**os.environ, **CONFIG.get('commandEnvironment', {}), 'CI': 'true'}
    if capture:
        return subprocess.check_output(command, env=environment, text=True)
    with (ROOT / 'deployment.log').open('a') as log:
        subprocess.run(command, env=environment, check=True, stdout=log, stderr=subprocess.STDOUT)


def variables():
    output = cli(['variable', 'list'], capture=True)
    for line in output.splitlines():
        try:
            values = json.loads(line)
        except ValueError:
            continue
        if isinstance(values, list):
            by_name = {item['name']: item.get('value') for item in values}
            return {name: by_name.get(name) for name in VARIABLES}
    raise ValueError('The Cloud CLI did not return a variable list.')


def snapshot():
    metrics = control('metrics', exact=True)
    compute = read_compute()
    require(clean(metrics), 'A stream or transaction is still active before the campaign.')
    require(metrics['server']['executable']['executableSha256'] == CONFIG['serverExecutableSha256'], 'Deploy the configured candidate before starting.')
    require(compute['minInstances'] == compute['maxInstances'] == 1, 'Exactly one instance is required.')
    original = {
        'metrics': metrics,
        'compute': compute,
        'variables': variables(),
        'protectedFiles': {path: sha256(path) for path in CONFIG.get('protectedFiles', [])},
    }
    save(ROOT / 'restoration-snapshot.json', original)
    return original


def restore():
    original = json.loads((ROOT / 'restoration-snapshot.json').read_text())
    for path, expected in original['protectedFiles'].items():
        require(sha256(path) == expected, 'Protected configuration changed: ' + path)

    before = control('metrics', exact=True)
    require(clean(before), 'The server must drain before restoration; recover and rerun restore.')
    require(before['server']['executable']['executableSha256'] == CONFIG['serverExecutableSha256'], 'An unrelated executable was deployed during the campaign.')
    current = read_compute()
    target = original['compute']
    require(current['minInstances'] == current['maxInstances'] == 1, 'The instance count changed outside the campaign.')
    if current['size'] != target['size']:
        resize(target['size'], current['size'], ROOT / 'restoration-compute.json')

    previous_variables = variables()
    if previous_variables != original['variables']:
        for name, value in original['variables'].items():
            if previous_variables[name] == value:
                continue
            if value is None:
                cli(['variable', 'unset', '--name', name])
            else:
                cli(['variable', 'set', '--name', name, '--value', value])
        cli(['deploy', '--redeploy', '--no-await'])

    expected = original['metrics']
    deadline = time.monotonic() + 900
    errors = []
    while True:
        try:
            metrics = control('metrics', exact=True)
            server = metrics['server']
            require(clean(metrics), 'Streams or transactions have not drained.')
            require(server['executable']['executableSha256'] == expected['server']['executable']['executableSha256'], 'Unexpected executable after restoration.')
            for key in ['benchmarkSchema', 'benchmarkDatabase', 'maxConnectionCount', 'sessionLogging']:
                require(server[key] == expected['server'][key], 'Restoration mismatch: ' + key)
            require(metrics['cpuCgroup']['quotaCores'] == expected['cpuCgroup']['quotaCores'], 'CPU quota has not returned to its original value.')
            require(metrics['memoryCgroup']['limitBytes'] == expected['memoryCgroup']['limitBytes'], 'Memory limit has not returned to its original value.')
            require(metrics['commitHints']['enabled'] == expected['commitHints']['enabled'], 'Commit hint settings changed.')
            require(variables() == original['variables'], 'Environment restoration did not persist.')
            for path, checksum in original['protectedFiles'].items():
                require(sha256(path) == checksum, 'Protected configuration changed during restoration.')
            save(ROOT / 'restoration-receipt.json', {'verified': True, 'metrics': metrics, 'errors': errors})
            state_path = ROOT / 'campaign-state.json'
            state = json.loads(state_path.read_text())
            state.update({'restorationRequired': False, 'currentSize': target['size'],
                          'currentSchema': server['benchmarkSchema'],
                          'currentQuota': metrics['cpuCgroup']['quotaCores']})
            save(state_path, state)
            return
        except Exception as error:
            errors.append(str(error))
            if time.monotonic() >= deadline:
                save(ROOT / 'restoration-receipt.json', {'verified': False, 'errors': errors})
                raise
            time.sleep(5)

