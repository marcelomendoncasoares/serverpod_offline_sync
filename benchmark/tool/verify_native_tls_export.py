"""Verify that a prepared workspace contains the measured runtime sources."""

import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workspace', type=Path)
    args = parser.parse_args()
    manifest = json.loads(
        (Path(__file__).parent.parent / 'native_tls/source-manifest.json').read_text()
    )

    actual = {}
    for scope in manifest['scopes']:
        path = args.workspace / scope
        files = [path] if path.is_file() else path.rglob('*.dart')
        for file in files:
            actual[str(file.relative_to(args.workspace))] = hashlib.sha256(
                file.read_bytes()
            ).hexdigest()

    mismatches = sorted(
        name for name in actual.keys() | manifest['files'].keys()
        if actual.get(name) != manifest['files'].get(name)
    )
    if mismatches:
        raise SystemExit('Runtime source mismatch:\n' + '\n'.join(mismatches))

    print(f'All {len(actual)} production Dart sources match the measured native build.')


if __name__ == '__main__':
    main()
