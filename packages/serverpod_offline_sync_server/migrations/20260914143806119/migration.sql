BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_sync_integrity_violations";

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_scopes";

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_scope_nodes";

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_scope_members";

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_data_rows";

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_rows" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "spaceId" INTEGER NOT NULL,
    "tblId" INTEGER NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "visibility" INTEGER NOT NULL DEFAULT (0),
    CONSTRAINT "crdt_data_rows_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_1" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_rows_space_tbl_row_idx" ON "crdt_data_rows" ("spaceId", "tblId", "uuidRowId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_integrity_violations" (
    "id" INTEGER PRIMARY KEY,
    "type" TEXT NOT NULL,
    "domainTableName" TEXT NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "ownerSpaceUuid" BLOB,
    "incomingSpaceUuid" BLOB NOT NULL,
    "operation" TEXT NOT NULL,
    "uuidNodeId" BLOB,
    "crdtDataRowId" INTEGER,
    "hlcDatetime" INTEGER,
    "hlcCounter" INTEGER,
    "firstSeenAt" INTEGER NOT NULL,
    "lastSeenAt" INTEGER NOT NULL,
    "occurrences" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "offline_sync_integrity_violations_key_idx" ON "offline_sync_integrity_violations" ("type", "operation", "domainTableName", "uuidRowId", "ownerSpaceUuid", "incomingSpaceUuid");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_space_members" (
    "id" INTEGER PRIMARY KEY,
    "spaceId" INTEGER NOT NULL,
    "userUuid" BLOB NOT NULL,
    "role" TEXT NOT NULL,
    CONSTRAINT "offline_sync_space_members_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "offline_sync_space_member_unique_idx" ON "offline_sync_space_members" ("userUuid", "spaceId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_space_nodes" (
    "id" INTEGER PRIMARY KEY,
    "spaceId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "lastReceivedHlc" BLOB,
    CONSTRAINT "offline_sync_space_nodes_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "offline_sync_space_nodes_fk_1" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "offline_sync_space_node_unique_idx" ON "offline_sync_space_nodes" ("spaceId", "nodeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_spaces" (
    "id" INTEGER PRIMARY KEY,
    "uuidSpaceId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "currentNodeId" INTEGER,
    CONSTRAINT "offline_sync_spaces_fk_0" FOREIGN KEY ("currentNodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

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
    VALUES ('serverpod_offline_sync', '20260914143806119', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260914143806119', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
