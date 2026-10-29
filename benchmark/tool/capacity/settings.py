"""Private configuration for the capacity runner; no credentials in reports."""

import hashlib
import json
import os
import re
from pathlib import Path


CONFIG_PATH = os.environ.get('CAPACITY_CONFIG')
CONFIG = json.loads(Path(CONFIG_PATH).read_text()) if CONFIG_PATH else {}
ROOT = Path(os.environ.get('CAPACITY_EVIDENCE', CONFIG.get('evidenceDirectory', '.'))).expanduser().resolve()
SIZES = ['small', 'medium', 'large', 'xlarge', 'xxlarge']


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def database(schema):
    name = CONFIG['databases'][schema]
    require(
        len(name) <= 63 and re.fullmatch(r'benchmark_capacity_' + schema + r'_[a-z0-9_]+', name),
        'Use an isolated benchmark_capacity database for each schema.',
    )
    return name


def secret():
    value = Path(CONFIG['secretFile']).expanduser().read_text().strip()
    require(bool(value), 'The benchmark secret file is empty.')
    return value


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.pending')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def validate_configuration():
    require(bool(CONFIG_PATH), 'Pass --config with a private configuration file.')
    require(CONFIG['target'].startswith(('https://', 'http://localhost:')), 'Unexpected benchmark target.')
    require(Path(CONFIG['client']).is_file(), 'Build the rounds client before starting.')
    require(sha256(CONFIG['client']) == CONFIG['clientSha256'], 'The client executable differs from its configured hash.')
    require(re.fullmatch(r'[0-9a-f]{64}', CONFIG['serverExecutableSha256']), 'Provide the deployed server SHA-256.')
    require(CONFIG.get('nativeTls') is True and CONFIG.get('pipelining') is False, 'This campaign measures native TLS without pipelining.')
    for schema in ['full', 'city']:
        database(schema)
    secret()

