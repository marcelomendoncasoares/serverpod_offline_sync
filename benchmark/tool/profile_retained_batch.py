"""Collect post-GC live heap at real sync frame and acknowledgement barriers.

Usage: DART=/path/to/dart python3 benchmark/tool/profile_retained_batch.py \
    /tmp/ack-memory baseline 1000 8192

The probe uses a disposable SQLite database and exposes its VM service only on
loopback. Retained payload counts are distinct from RSS or peak capture memory.
"""

import json
import hashlib
import os
import re
import queue
import threading
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

repository = Path(__file__).resolve().parents[2]
root = Path(sys.argv[1]).resolve()
root.mkdir(parents=True, exist_ok=True)
label = sys.argv[2]
assert label and all(c.isalnum() or c in '-_' for c in label)
assert not (root / (label + '.json')).exists(), 'Use a fresh result label.'
rows = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
payload = int(sys.argv[4]) if len(sys.argv) > 4 else 8192
assert rows > 0 and payload >= 16
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
command = [os.environ.get('DART', 'dart'), f'--enable-vm-service={port}/127.0.0.1', 'run', 'benchmark/tool/retained_batch_probe.dart', str(rows), str(payload)]
source_files = {name: hashlib.sha256((repository / name).read_bytes()).hexdigest() for name in ['packages/serverpod_offline_sync/lib/src/sync/session.dart', 'packages/serverpod_offline_sync/lib/src/sync/space_state.dart', 'benchmark/tool/retained_batch_probe.dart']}
process = subprocess.Popen(command, cwd=repository, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.PIPE, text=True, bufsize=1)
lines = queue.Queue()

def read_lines():
    for line in process.stdout:
        lines.put(line)
    lines.put(None)

threading.Thread(target=read_lines, daemon=True).start()
uri = None
isolate = None
stages = []

def rpc(method, **parameters):
    assert uri
    with urllib.request.urlopen(uri + method + '?' + urllib.parse.urlencode(parameters), timeout=45) as response:
        value = json.load(response)
    assert 'error' not in value, value
    return value['result']

try:
    with (root / (label + '.log')).open('w') as log:
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=1)
            except queue.Empty:
                continue
            if line is None:
                break
            log.write(line)
            log.flush()
            match = re.search(r'Dart VM service is listening on (http://127.0.0.1:[^\s]+)', line)
            if match:
                uri = match.group(1).rstrip('/') + '/'
            if not line.startswith('{'):
                continue
            stage = json.loads(line)
            if 'stage' not in stage:
                continue
            if isolate is None:
                vm = rpc('getVM')
                isolate = next(i['id'] for i in vm['isolates'] if i['name'] == 'main')
                (root / (label + '-vm.json')).write_text(json.dumps(vm, indent=2) + '\n')
            heap = rpc('getAllocationProfile', isolateId=isolate, gc='true')
            (root / (label + '-' + stage['stage'] + '-heap.json')).write_text(json.dumps(heap) + '\n')
            stage['memoryUsage'] = heap['memoryUsage']
            stage['selectedObjects'] = {c['class']['name']: {'instances': c['instancesCurrent'], 'bytes': c['bytesCurrent']} for c in heap['members'] if c['class']['name'] in ['_SyncSession', '_SentBatch', '_CrdtMergeInsertImpl', '_PersonImpl', 'Hlc', '_HlcImpl']}
            stages.append(stage)
            print(json.dumps(stage), flush=True)
            next_command = {'seeded': 'open', 'held': 'acknowledge', 'acknowledged': 'write', 'closed': 'finish'}[stage['stage']]
            process.stdin.write(next_command + '\n')
            process.stdin.flush()
        code = process.wait(timeout=15)
        assert code == 0, f'Probe failed with {code}; see log'
        assert [s['stage'] for s in stages] == ['seeded','held','acknowledged','closed'], stages
        assert all(s['activeTransactions'] == 0 for s in stages)
finally:
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    (root / (label + '.json')).write_text(json.dumps({'label': label, 'rows': rows, 'payloadBytesPerRow': payload, 'command': command, 'sourceFiles': source_files, 'stages': stages, 'exitCode': process.returncode}, indent=2) + '\n')
