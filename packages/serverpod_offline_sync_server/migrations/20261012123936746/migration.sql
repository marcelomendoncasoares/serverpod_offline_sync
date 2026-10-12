BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_nodes" (
    "id" INTEGER PRIMARY KEY,
    "uuidNodeId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "localUserUuid" BLOB,
    "lastHlc" BLOB
) STRICT;

INSERT INTO "new_crdt_nodes" ("id", "uuidNodeId", "lastHlc") SELECT "id", "uuidNodeId", "lastHlc" FROM "crdt_nodes";
DROP TABLE "crdt_nodes";
ALTER TABLE "new_crdt_nodes" RENAME TO "crdt_nodes";

-- Indexes
CREATE UNIQUE INDEX "crdt_nodes__uuidNodeId__unique_idx" ON "crdt_nodes" ("uuidNodeId");

-- Indexes
CREATE UNIQUE INDEX "crdt_nodes_local_user_idx" ON "crdt_nodes" ("localUserUuid");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_offline_sync_spaces" (
    "id" INTEGER PRIMARY KEY,
    "uuidSpaceId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "lastHlc" BLOB
) STRICT;

INSERT INTO "new_offline_sync_spaces" ("id", "uuidSpaceId") SELECT "id", "uuidSpaceId" FROM "offline_sync_spaces";
DROP TABLE "offline_sync_spaces";
ALTER TABLE "new_offline_sync_spaces" RENAME TO "offline_sync_spaces";

-- Indexes
CREATE UNIQUE INDEX "offline_sync_spaces__uuidSpaceId__unique_idx" ON "offline_sync_spaces" ("uuidSpaceId");

--
-- STORE COLUMN TYPES FOR MIGRATIONS
--
DROP TABLE IF EXISTS "serverpod_sqlite_schema";

CREATE TABLE "serverpod_sqlite_schema" (
    "table_name" TEXT NOT NULL,
    "column_name" TEXT NOT NULL,
    "column_type" TEXT NOT NULL,
    "column_vector_dimension" INTEGER,
    PRIMARY KEY ("table_name", "column_name")
);

INSERT INTO "serverpod_sqlite_schema" VALUES
    ('crdt_data_attempted_value', 'value', 'jsonb', NULL),
    ('crdt_data_fields', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'uuidRowId', 'uuid', NULL),
    ('crdt_data_tombstone', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_nodes', 'uuidNodeId', 'uuid', NULL),
    ('crdt_nodes', 'localUserUuid', 'uuid', NULL),
    ('crdt_nodes', 'lastHlc', 'jsonb', NULL),
    ('crdt_schema_columns', 'isNullable', 'boolean', NULL),
    ('offline_sync_integrity_violations', 'uuidRowId', 'uuid', NULL),
    ('offline_sync_integrity_violations', 'ownerSpaceUuid', 'uuid', NULL),
    ('offline_sync_integrity_violations', 'incomingSpaceUuid', 'uuid', NULL),
    ('offline_sync_integrity_violations', 'uuidNodeId', 'uuid', NULL),
    ('offline_sync_integrity_violations', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('offline_sync_integrity_violations', 'firstSeenAt', 'timestampWithoutTimeZone', NULL),
    ('offline_sync_integrity_violations', 'lastSeenAt', 'timestampWithoutTimeZone', NULL),
    ('offline_sync_space_members', 'userUuid', 'uuid', NULL),
    ('offline_sync_space_nodes', 'lastReceivedHlc', 'jsonb', NULL),
    ('offline_sync_spaces', 'uuidSpaceId', 'uuid', NULL),
    ('offline_sync_spaces', 'lastHlc', 'jsonb', NULL),
    ('serverpod_cloud_storage', 'addedTime', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage', 'expiration', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage', 'verified', 'boolean', NULL),
    ('serverpod_cloud_storage_direct_download', 'expiration', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage_direct_upload', 'expiration', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage_direct_upload', 'preventOverwrite', 'boolean', NULL),
    ('serverpod_future_call', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_future_call', 'scheduling', 'json', NULL),
    ('serverpod_future_call_claim', 'lastHeartbeatTime', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_connection_info', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_metric', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_metric', 'isHealthy', 'boolean', NULL),
    ('serverpod_log', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_message_log', 'slow', 'boolean', NULL),
    ('serverpod_migrations', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_query_log', 'slow', 'boolean', NULL),
    ('serverpod_runtime_settings', 'logSettings', 'json', NULL),
    ('serverpod_runtime_settings', 'logSettingsOverrides', 'json', NULL),
    ('serverpod_runtime_settings', 'logServiceCalls', 'boolean', NULL),
    ('serverpod_runtime_settings', 'logMalformedCalls', 'boolean', NULL),
    ('serverpod_session_log', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_session_log', 'slow', 'boolean', NULL),
    ('serverpod_session_log', 'isOpen', 'boolean', NULL),
    ('serverpod_session_log', 'touched', 'timestampWithoutTimeZone', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20261012123936746', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012123936746', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
