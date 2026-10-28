# Frozen upstream pipelining driver

Source: https://github.com/nielsenko/postgresql-dart
Requested ref: `cloud-test`
Commit: `9c4cbc007327444944bef83f20d0e9e48e8ec84e`
Captured: 2026-10-28

All files under `lib/` and `LICENSE` are byte-for-byte copies of that commit.
No runtime changes are applied here. The package manifest opts into this
private Dart workspace and marks the package non-publishable.

During the first Cloud comparison, upstream rewrote `cloud-test`, making the
original `3a05c586` snapshot unavailable to a clean dependency checkout.
This copy was refreshed with `dart pub upgrade` after that update. Vendoring
preserves the exact upgraded implementation for measurement and reproduction.
The first snapshot and its controls remain recorded separately.
This copy retains its original license. It is not a replacement upstream release.
