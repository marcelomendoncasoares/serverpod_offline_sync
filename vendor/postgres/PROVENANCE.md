# Frozen upstream pipelining driver

Source: https://github.com/nielsenko/postgresql-dart
Requested ref: `cloud-test`
Commit: `3a05c58697454816f386017f9c9ad89191a08929`
Captured: 2026-10-28

All files under `lib/` and `LICENSE` are byte-for-byte copies of that commit.
No runtime changes are applied here. The package manifest opts into this
private Dart workspace and marks the package non-publishable.

During the Cloud comparison, upstream rewrote `cloud-test` to
`9c4cbc007327444944bef83f20d0e9e48e8ec84e`. Cloud's clean dependency checkout
could no longer resolve the original commit. Vendoring preserves the exact
already-tested implementation for the remaining controls and reproduction.
This copy retains its original license. It is not a replacement upstream release.
