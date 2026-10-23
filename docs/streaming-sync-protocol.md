# Streaming sync protocol

Finite and continuous synchronization use the same bidirectional streaming endpoint. Client and server must use the same protocol; this experimental package does not negotiate an older wire format.

## Initialization and permissions

Each peer sends `Connect` with its node identity, schema hash and space grants, followed by per-space `SinceHlc` resume vectors. The server supplies authoritative grants. A follower's cached grants never authorize access on the server.

The authoritative peer sends `Ready` after its grants and initial cursors are available. Continuous followers advertise readiness after initialization. A finite follower prepares its upload before sending `Ready`, allowing readiness and the upload to arrive together. Incoming batches require peer readiness and the expected batch identifier.

The server checks write permission after merge admission, inside the transaction, and locks the membership row until the merge commits. Trusted replication into a follower can update a locally read-only space.

## Independent transfer and durable acknowledgement

A sender captures all pending changes in one consistent database snapshot. It emits numbered `MergeChunk` frames and an `EndOfBatch` carrying the same batch identifier. Each direction permits one outstanding batch. A control reader continues receiving while the serial merger applies a complete incoming batch.

The receiver merges each space atomically with its source checkpoints. It emits `Committed` only after every accepted space in that batch has completed its merge. The sender advances its session checkpoints only on the matching acknowledgement. No database transaction spans a peer acknowledgement or idle stream wait.

An exact fact received and committed on the current stream can be omitted from the return traffic. This suppression compares complete encoded facts, and checkpoint advancement still requires complete snapshot enumeration. A higher clock by itself never proves an older fact was received.

## Finite completion

A finite follower sends one upload with `finalForOnce: true`. After the server commits that upload, the server captures and sends its final download boundary. An already complete upload being applied can defer a redundant server capture; partial uploads and continuous sessions still permit both directions to progress.

The follower finishes once its upload has been acknowledged and it has applied the final download. It sends the download acknowledgement before closing its output. The server finishes when it receives that acknowledgement. There is no additional final-confirmation frame. Concurrent writes beyond those captured boundaries belong to a later synchronization.

## Continuous wakeup and cleanup

Local tracked commits notify subscribed streams after the transaction succeeds. Notifications coalesce capture work and carry no checkpoint authority. A shared periodic scan compares durable space revisions and membership across subscribed streams. Every tracked write changes the revision, including received facts older than the greatest HLC. Recovery records a locally announced revision only after successful notification, still wakes for an unknown initial baseline, and joins scans borrowing a closing stream's session. Revisions never authorize checkpoint advancement. An optional [commit-hint transport](commit-hints.md) can wake streams across processes sooner; periodic recovery remains enabled for lost notifications and membership changes.

Cancellation signals the active merge's native rollback and waits for SQL and callbacks to settle before releasing the session. An executing SQL statement is not forcibly interrupted, and cancellation cannot undo a transaction already committing.

## Memory limits

The implementation buffers complete outbound snapshots and incoming batches. One outstanding batch limits protocol concurrency, not bytes or peak backlog memory. Any future storage bound must preserve complete snapshot enumeration and durable checkpoint correctness.
