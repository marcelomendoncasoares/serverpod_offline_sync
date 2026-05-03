#!/usr/bin/env python3
"""Fix generated merge protocol files missing the _Undefined sentinel class.

Serverpod 3.5.0-beta.5 currently generates merge model files with dynamic fields
that reference `_Undefined` in `copyWith(...)` without emitting the helper class
declaration. This script patches the generated files immediately after code
generation so analyze and test jobs can compile the generated output.
"""

from pathlib import Path


def main() -> None:
    paths = (
        Path(
            "packages/serverpod_offline_sync_client/lib/src/protocol/merge/insert.dart"
        ),
        Path(
            "packages/serverpod_offline_sync_client/lib/src/protocol/merge/update.dart"
        ),
        Path(
            "packages/serverpod_offline_sync_server/lib/src/generated/merge/insert.dart"
        ),
        Path(
            "packages/serverpod_offline_sync_server/lib/src/generated/merge/update.dart"
        ),
    )

    for path in paths:
        text = path.read_text()
        if "Object? data = _Undefined" not in text:
            continue
        if "class _Undefined {}" in text:
            continue
        path.write_text(f"{text.rstrip()}\n\nclass _Undefined {{}}\n")


if __name__ == "__main__":
    main()
