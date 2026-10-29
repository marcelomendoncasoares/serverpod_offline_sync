from settings import CONFIG, database, require

"""Wait for a clean instance after a failed owned benchmark; preserve failure."""

import json
import time

from cloud import ROOT, clean, control, save


class ChangedExecutableError(RuntimeError):
    pass


def ensure_recovered(label):
    state = json.loads((ROOT / 'campaign-state.json').read_text())
    deadline = time.monotonic() + 900
    errors = []
    print(json.dumps({'waitingForRecovery': label}), flush=True)
    while True:
        try:
            metrics = control('metrics', exact=True)
            server = metrics['server']
            if server['executable']['executableSha256'] != state['nativeExecutableSha256']:
                raise ChangedExecutableError('The deployed executable changed outside this campaign')
            require(clean(metrics), 'Waiting for streams and idle transactions to drain')
            require(server['benchmarkSchema'] == state['currentSchema'], "Campaign verification failed: server['benchmarkSchema'] == state['currentSchema']")
            require(server['benchmarkDatabase'] == database(state['currentSchema']), "Campaign verification failed: server['benchmarkDatabase'] == database(state['currentSchema'])")
            require(metrics['cpuCgroup']['quotaCores'] == state['currentQuota'], "Campaign verification failed: metrics['cpuCgroup']['quotaCores'] == state['currentQuota']")
            require(server['maxConnectionCount'] == 100, "Campaign verification failed: server['maxConnectionCount'] == 100")
            require(not server['sessionLogging']['persistentEnabled'], "Campaign verification failed: not server['sessionLogging']['persistentEnabled']")
            require(not server['sessionLogging']['consoleEnabled'], "Campaign verification failed: not server['sessionLogging']['consoleEnabled']")
            require(not metrics['commitHints']['enabled'], "Campaign verification failed: not metrics['commitHints']['enabled']")
            save(label + '-recovery.json', {
                'metrics': metrics,
                'readinessErrors': errors,
                'note': 'Recovery does not change the failed run verdict.',
            })
            print(json.dumps({'recoveredAfter': label, 'instance': server['instanceId']}), flush=True)
            return
        except ChangedExecutableError:
            raise
        except Exception as error:
            errors.append(str(error))
            if time.monotonic() >= deadline:
                save(label + '-recovery-failed.json', {'errors': errors})
                raise
            time.sleep(5)
