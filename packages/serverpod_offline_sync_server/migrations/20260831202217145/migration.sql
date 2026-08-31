BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "serverpod_cloud_storage" ADD COLUMN "contentType" TEXT;
ALTER TABLE "serverpod_cloud_storage" ADD COLUMN "cacheControl" TEXT;
ALTER TABLE "serverpod_cloud_storage" ADD COLUMN "contentDisposition" TEXT;
ALTER TABLE "serverpod_cloud_storage" ADD COLUMN "contentEncoding" TEXT;
ALTER TABLE "serverpod_cloud_storage" ADD COLUMN "customMetadata" TEXT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_cloud_storage_direct_download" (
    "id" INTEGER PRIMARY KEY,
    "storageId" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "authKey" TEXT NOT NULL,
    "downloadFileName" TEXT,
    "contentType" TEXT
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_download_auth_key" ON "serverpod_cloud_storage_direct_download" ("authKey");
CREATE INDEX "serverpod_cloud_storage_direct_download_expiration" ON "serverpod_cloud_storage_direct_download" ("expiration");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_serverpod_cloud_storage_direct_upload" (
    "id" INTEGER PRIMARY KEY,
    "storageId" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "authKey" TEXT NOT NULL,
    "maxFileSize" INTEGER NOT NULL DEFAULT (10485760),
    "contentLength" INTEGER,
    "preventOverwrite" INTEGER NOT NULL DEFAULT (0),
    "contentType" TEXT,
    "cacheControl" TEXT,
    "contentDisposition" TEXT,
    "contentEncoding" TEXT,
    "customMetadata" TEXT
) STRICT;

INSERT INTO "new_serverpod_cloud_storage_direct_upload" ("id", "storageId", "path", "expiration", "authKey") SELECT "id", "storageId", "path", "expiration", "authKey" FROM "serverpod_cloud_storage_direct_upload";
DROP TABLE "serverpod_cloud_storage_direct_upload";
ALTER TABLE "new_serverpod_cloud_storage_direct_upload" RENAME TO "serverpod_cloud_storage_direct_upload";

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_upload_storage_path" ON "serverpod_cloud_storage_direct_upload" ("storageId", "path");

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
    ('crdt_data_fields', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_foreign_key', 'attemptedValue', 'uuid', NULL),
    ('crdt_data_foreign_key', 'visibleValue', 'uuid', NULL),
    ('crdt_data_rows', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'uuidRowId', 'uuid', NULL),
    ('crdt_data_tombstone', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_nodes', 'uuidNodeId', 'uuid', NULL),
    ('crdt_nodes', 'lastHlc', 'jsonb', NULL),
    ('crdt_scope_members', 'userUuid', 'uuid', NULL),
    ('crdt_scope_nodes', 'lastReceivedHlc', 'jsonb', NULL),
    ('crdt_scopes', 'uuidScopeId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'uuidRowId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'ownerScopeUuid', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'incomingScopeUuid', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'uuidNodeId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_sync_integrity_violations', 'firstSeenAt', 'timestampWithoutTimeZone', NULL),
    ('crdt_sync_integrity_violations', 'lastSeenAt', 'timestampWithoutTimeZone', NULL),
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
    VALUES ('serverpod_offline_sync', '20260831202217145', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260831202217145', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
