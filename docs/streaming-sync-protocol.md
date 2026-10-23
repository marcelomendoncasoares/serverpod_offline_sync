# Streaming sync protocol

Finite and continuous synchronization use the same bidirectional streaming endpoint. Client and server must use the same protocol; this experimental package does not negotiate an older wire format.

## Initialization and permissions

Each peer sends `Connect` with its replica epoch, schema hash and space grants, followed by per-space `SinceRevision` receipts. A receipt identifies the sender epoch and the highest completely applied revision from that sender. The durable local node UUID is the replica epoch; recreating a database creates a new epoch. A sender ignores receipts for other epochs and rejects a receipt beyond its own committed revision. The server supplies authoritative grants. A follower's cached grants never authorize access on the server.

Restoring a backup or replacing replica state must assign a fresh replica epoch. Create a new local clock node while preserving the UUIDs of previously authored facts; do not rewrite historical author identities. Reusing an epoch after rolling back committed state invalidates both receipts and immediate-source provenance. The future-cursor guard runs when a space is captured for sending; it is not a restore detector for read-only spaces or for a restored revision that has already caught up numerically.

Immediate peer identities are interned once per connection as `(authenticated user UUID, replica epoch)`. Receipts also belong to a space. Payload author IDs describe CRDT ordering and never establish immediate-peer knowledge or delivery completeness.

The authoritative peer sends `Ready` after its grants and initial cursors are available. Continuous followers advertise readiness after initialization. A finite follower prepares its upload before sending `Ready`, allowing readiness and the upload to arrive together. Incoming batches require peer readiness and the expected batch identifier.

The server checks write permission after merge admission, inside the transaction, and locks the membership row until the merge commits. Trusted replication into a follower can update a locally read-only space.

## Independent transfer and durable acknowledgement

A space has a monotonically increasing, replica-local revision. Effective authored fact changes in an atomic space transaction share its next revision, allocated while holding the space lock. Insertions, field values and tombstones each carry their own revision and immediate source peer. A mixed row can therefore contain both locally authored and received facts. Projection does not turn projected values into authored facts, and a no-op replay does not allocate another revision or change provenance.

A sender captures the committed space bound, pending fact metadata and authored values in one repeatable-read snapshot. It selects facts after the receiver's receipt and omits facts durably sourced from that immediate peer. A complete capture covers every effective fact through its bound, including late relayed changes with older author HLCs. HLC maxima remain causal and reporting metadata; they are not delivery checkpoints.

The sender emits numbered `MergeChunk` frames and an `EndOfBatch` carrying the same batch identifier and captured revision for each space whose facts were sent. Each direction permits one outstanding batch. A control reader continues receiving while the serial merger applies a complete incoming batch.

The receiver merges each space's data and sender-epoch receipt in the same transaction. It emits `Committed` only after every accepted space in that batch has committed. The sender advances the corresponding session cursors only on the matching acknowledgement. A lost acknowledgement is safe: reconnect advertises the already committed receipt. Cancellation before commit rolls back both facts and receipt. No database transaction spans a peer acknowledgement or idle stream wait.

When a complete capture contains no facts for a space, the sender may advance only that space's in-session scan cursor. Every skipped fact was either below the acknowledged cursor or durably sourced from that peer. Continuous sync sends no empty batch for this scan, including when another space has data. Reconnect conservatively recaptures from the durable receipt. Finite sync still sends its completion boundary, which can have an empty receipt list. There is no encoded-fact echo cache. A duplicate received from a different peer can be returned once; its unchanged revision and the next durable receipt prevent a repeating cycle.

## Finite completion

A finite follower sends one upload with `finalForOnce: true`. After the server commits that upload, the server captures and sends its final download boundary. An already complete upload being applied can defer a redundant server capture; partial uploads and continuous sessions still permit both directions to progress.

The follower finishes once its upload has been acknowledged and it has applied the final download. It sends the download acknowledgement before closing its output. The server finishes when it receives that acknowledgement. There is no additional final-confirmation frame. Concurrent writes beyond those captured boundaries belong to a later synchronization.

## Continuous wakeup and cleanup

Local tracked commits notify subscribed streams after the transaction succeeds. Notifications coalesce capture work and carry no checkpoint authority. A shared periodic scan compares durable space revisions and membership across subscribed streams. Every tracked write changes the revision, including received facts older than the greatest HLC. Recovery records a locally announced revision only after successful notification, still wakes for an unknown initial baseline, and joins scans borrowing a closing stream's session. Revisions never authorize checkpoint advancement.

Cancellation signals the active merge's native rollback and waits for SQL and callbacks to settle before releasing the session. An executing SQL statement is not forcibly interrupted, and cancellation cannot undo a transaction already committing.

## Memory limits

After capture, acknowledgement bookkeeping retains only each space's captured revision and maximum callback clock, allowing consumed frames to release row payloads. The captured revision advances delivery progress only after the matching acknowledgement. Callback clocks report committed facts and do not control delivery.

The implementation buffers complete outbound snapshots and incoming batches. One outstanding batch limits protocol concurrency, not bytes or peak backlog memory. Any future storage bound must preserve complete snapshot enumeration and durable checkpoint correctness.
