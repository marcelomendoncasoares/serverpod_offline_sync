import 'dart:async';

import 'package:uuid/uuid.dart';

import '../hlc/hlc.dart';

/// Callback function for when a merge is successful.
typedef OfflineSyncOnMergeSuccess =
    FutureOr<void> Function(OfflineSyncMergeEvent event);

/// One space's synchronization activity in one sync cycle, reported to an
/// [OfflineSyncOnMergeSuccess] observer after the activity committed locally.
///
/// Emitted per space and per cycle, and only when the cycle moved data for that
/// space: an idle cycle reports nothing. Direction is relative to the node
/// observing the event, so the same exchange is inbound on one peer and
/// outbound on the other.
///
/// The event stays at space level on purpose. A replayed or stale fact can
/// merge successfully without changing a visible row, and foreign-key or unique
/// projection can touch rows the batch never mentioned, so an observer that
/// needs row details queries the committed state instead of reading them here.
final class OfflineSyncMergeEvent {
  /// Creates an event describing what [spaceUuid] synchronized in one cycle.
  const OfflineSyncMergeEvent({
    required this.syncingUserId,
    required this.spaceUuid,
    required this.peerNodeId,
    required this.syncedHlc,
    this.receivedHlc,
    this.sentHlc,
  });

  /// User whose sync session is running.
  ///
  /// On the server this is the authenticated user, never an incoming claimed
  /// user id. It identifies the uploading user for inbound activity, not
  /// necessarily the original author of every replicated fact.
  final UuidValue syncingUserId;

  /// Public UUID of the affected personal or shared space.
  ///
  /// Distinct from the syncing user and from the database's integer space id.
  final UuidValue spaceUuid;

  /// Remote replica id from the sync handshake.
  ///
  /// Metadata, not an authenticated user identity.
  final UuidValue peerNodeId;

  /// Combined progress value of the space checkpoint and the received HLC.
  ///
  /// Not a unique event id.
  final Hlc syncedHlc;

  /// Highest incoming HLC in this batch committed locally, or `null` when there
  /// was no inbound merge for this space.
  final Hlc? receivedHlc;

  /// Highest outgoing HLC sent for this space in this batch, or `null` when
  /// nothing was sent.
  ///
  /// Transmission does not establish remote commit acknowledgement.
  final Hlc? sentHlc;

  @override
  String toString() =>
      'OfflineSyncMergeEvent(syncingUserId: $syncingUserId, '
      'spaceUuid: $spaceUuid, peerNodeId: $peerNodeId, '
      'syncedHlc: $syncedHlc, receivedHlc: $receivedHlc, sentHlc: $sentHlc)';
}
