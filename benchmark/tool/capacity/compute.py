"""Serverpod Cloud compute adapter. Auth stays in the local CLI credential file."""

import base64
import datetime
import json
import urllib.request
from pathlib import Path

from settings import CONFIG, SIZES, require, save


def call(method, body):
    auth_path = Path(CONFIG.get('cloudAuthFile', '~/.serverpod/cloud/serverpod_cloud_auth.json')).expanduser()
    token = json.loads(auth_path.read_text())['token']
    parts = token.split(':')
    if len(parts) == 3 and parts[0] == 'sas':
        token = base64.urlsafe_b64encode(
            parts[0].encode()
            + base64.urlsafe_b64decode(parts[1])
            + base64.urlsafe_b64decode(parts[2])
        ).decode()

    request = urllib.request.Request(
        'https://api.serverpod.dev/compute/' + method,
        json.dumps({'cloudCapsuleId': CONFIG['project'], **body}).encode(),
        {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token},
    )
    with urllib.request.urlopen(request, timeout=40) as response:
        return json.load(response)


def read_compute():
    return call('readCompute', {})


def resize(size, expected, receipt_path):
    before = read_compute()
    require(size in SIZES, 'Unknown compute size.')
    require(before['size'] == expected, 'Compute changed outside this campaign.')
    require(before['minInstances'] == before['maxInstances'] == 1, 'This campaign requires exactly one instance.')
    receipt = {
        'time': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'before': before,
        'requested': {'size': size, 'minInstances': 1, 'maxInstances': 1},
    }
    save(receipt_path, receipt)
    receipt['after'] = call('updateCompute', receipt['requested'])
    save(receipt_path, receipt)
    return receipt['after']

