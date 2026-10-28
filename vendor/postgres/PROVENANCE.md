# Matched PostgreSQL driver for the native TLS experiment

This private workspace package contains the exact driver `lib/` sources used
by the matched Dart/native TLS builds in the
[2026-10-28 experiment](../../docs/sync-native-tls-benchmark-2026-10-28.md).
It is not a new upstream driver release.

- Source: <https://github.com/nielsenko/postgresql-dart/tree/d392eada9e802c579719f1a1497c14d028cf3ff6>
- Retained optimizations: TCP_NODELAY on the ordinary socket path, inline
  transaction portal close, and cancellation drainage from
  <https://github.com/marcelomendoncasoares/postgresql-dart/tree/79560a928c6b9307e89fe52f368f68dfce01eb79>.
- Exact patch relative to the supplied connector branch:
  [retain-existing-driver-optimizations.patch](../../docs/benchmark-evidence/native-tls-2026-10-28/retain-existing-driver-optimizations.patch).
- Original license is retained in `LICENSE`.

Only runtime source, manifest, license, and this provenance are vendored.
The manifest uses Dart workspace resolution, requires Dart 3.12.2 or later,
and disables publishing. No driver runtime source was changed while publishing
this experiment branch.

The explicit workspace membership is intentional: the tested Cloud uploader
omitted a driver referenced only through a path override. Both TLS comparison
builds must use this same package and the same dependency pins.
