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

    # prepare_cloud writes JSON-compatible YAML, so this check needs no YAML
    # package and verifies the normal manifests uploaded by scloud.
    root_spec = json.loads((args.workspace / 'pubspec.yaml').read_text())
    server_spec = json.loads(
        (args.workspace / 'benchmark/pubspec.yaml').read_text()
    )
    if root_spec['dependency_overrides'] != manifest['dependencyOverrides']:
        raise SystemExit('Dependency overrides differ from the measured build.')
    if server_spec['dependencies']['postgres_tls'] != manifest['nativeTlsDependency']:
        raise SystemExit('Native TLS dependency differs from the measured build.')

    print(f'All {len(actual)} runtime sources and dependency pins match the pipeline build.')


if __name__ == '__main__':
    main()
