import 'package:clock/clock.dart';

import 'dst_random.dart';
import 'dst_snapshot.dart';
import 'dst_world.dart';

/// What a replica exports must reproduce what it holds.
///
/// Every other property inspects a database after a merge, so all of them are
/// blind to the collection path: a replica could hold correct state and still
/// describe it wrongly on the wire, and the only symptom would be a peer
/// disagreeing later, for reasons that look like a merge defect.
///
/// This closes that gap with an independent oracle. A replica's own export,
/// merged into an empty replica, has to land on the same visible state. It
/// needs no peer and no scheduling luck: one replica plus a mirror is enough,
/// and a mismatch localizes the fault to collection rather than merge.
///
/// The comparison is per scope, because that is the unit a replica exports.
/// [expected] is the caller's already-captured snapshot of [source]. Nothing
/// mutates the source between the two, and a capture is a dozen queries, so it
/// is passed in rather than taken again.
Future<List<DstViolation>> exportRoundTrip({
  required DstReplica source,
  required DstSnapshot expected,
  required DstIds ids,
  required Clock clock,
}) async {
  final violations = <DstViolation>[];

  for (final scopeUuid in source.scopeUuids) {
    final changes = await source.collect(scopeUuid);

    // The mirror knows nothing except this one scope, so anything the export
    // leaves out simply is not there to be found.
    final mirror = await DstReplica.create(
      name: '${source.name}~mirror',
      scopeUuids: [scopeUuid],
      nodeUuid: ids.next(),
      clock: clock,
    );
    try {
      await mirror.merge(changes, scopeUuid);
    } on Exception catch (exception) {
      // Refusing the export outright is the worst round-trip outcome, not an
      // error to propagate: this is the path a client takes on its first sync,
      // so an export that cannot be merged into an empty replica means a new
      // client could never finish bootstrapping from it.
      violations.add((
        property: 'exportRoundTrip',
        detail:
            'the export of ${source.name} for scope $scopeUuid cannot be '
            'merged into an empty replica, so a first sync would fail: '
            '$exception',
      ));
      continue;
    }

    final rendered = (await DstSnapshot.capture(mirror)).renderScope(scopeUuid);
    final original = expected.renderScope(scopeUuid);
    if (rendered == original) continue;

    violations.add((
      property: 'exportRoundTrip',
      detail:
          'scope $scopeUuid does not survive a round trip through the export '
          'of ${source.name} (${changes.length} changes)\n'
          '--- ${source.name} holds ---\n$original'
          '--- its export produces ---\n$rendered',
    ));
  }

  return violations;
}
