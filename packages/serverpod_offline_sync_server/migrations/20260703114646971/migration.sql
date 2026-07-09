BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_fields" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "columnId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_fields_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_1" FOREIGN KEY ("columnId") REFERENCES "crdt_schema_columns" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_fields_row_column_idx" ON "crdt_data_fields" ("rowId", "columnId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_foreign_key" (
    "id" INTEGER PRIMARY KEY,
    "fieldId" INTEGER NOT NULL,
    "attemptedValue" BLOB,
    "visibleValue" BLOB,
    "overrideReason" INTEGER,
    CONSTRAINT "crdt_data_foreign_key_fk_0" FOREIGN KEY ("fieldId") REFERENCES "crdt_data_fields" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_foreign_key_field_idx" ON "crdt_data_foreign_key" ("fieldId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_rows" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "scopeId" INTEGER NOT NULL,
    "tblId" INTEGER NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "visibility" INTEGER NOT NULL DEFAULT (0),
    CONSTRAINT "crdt_data_rows_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_1" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_rows_scope_tbl_row_idx" ON "crdt_data_rows" ("scopeId", "tblId", "uuidRowId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_tombstone" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "clFlag" INTEGER NOT NULL,
    "reason" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_tombstone_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_tombstone_fk_1" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_tombstone_row_idx" ON "crdt_data_tombstone" ("rowId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_nodes" (
    "id" INTEGER PRIMARY KEY,
    "uuidNodeId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "lastHlc" BLOB
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_nodes__uuidNodeId__unique_idx" ON "crdt_nodes" ("uuidNodeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_schema_columns" (
    "id" INTEGER PRIMARY KEY,
    "tblId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    CONSTRAINT "crdt_schema_columns_fk_0" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_schema_columns_table_column_idx" ON "crdt_schema_columns" ("tblId", "name");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_schema_tables" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_schema_tables__name__unique_idx" ON "crdt_schema_tables" ("name");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_scope_members" (
    "id" INTEGER PRIMARY KEY,
    "scopeId" INTEGER NOT NULL,
    "userUuid" BLOB NOT NULL,
    "role" TEXT NOT NULL,
    CONSTRAINT "crdt_scope_members_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_scope_member_unique_idx" ON "crdt_scope_members" ("userUuid", "scopeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_scope_nodes" (
    "id" INTEGER PRIMARY KEY,
    "scopeId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "lastReceivedHlc" BLOB,
    CONSTRAINT "crdt_scope_nodes_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_scope_nodes_fk_1" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_scope_node_unique_idx" ON "crdt_scope_nodes" ("scopeId", "nodeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_scopes" (
    "id" INTEGER PRIMARY KEY,
    "uuidScopeId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "currentNodeId" INTEGER,
    CONSTRAINT "crdt_scopes_fk_0" FOREIGN KEY ("currentNodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_scopes__uuidScopeId__unique_idx" ON "crdt_scopes" ("uuidScopeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_sync_integrity_violations" (
    "id" INTEGER PRIMARY KEY,
    "type" TEXT NOT NULL,
    "domainTableName" TEXT NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "ownerScopeUuid" BLOB,
    "incomingScopeUuid" BLOB NOT NULL,
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
CREATE UNIQUE INDEX "crdt_sync_integrity_violations_key_idx" ON "crdt_sync_integrity_violations" ("type", "operation", "domainTableName", "uuidRowId", "ownerScopeUuid", "incomingScopeUuid");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_cloud_storage" (
    "id" INTEGER PRIMARY KEY,
    "storageId" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "addedTime" INTEGER NOT NULL,
    "expiration" INTEGER,
    "byteData" BLOB NOT NULL,
    "verified" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_path_idx" ON "serverpod_cloud_storage" ("storageId", "path");
CREATE INDEX "serverpod_cloud_storage_expiration" ON "serverpod_cloud_storage" ("expiration");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_cloud_storage_direct_upload" (
    "id" INTEGER PRIMARY KEY,
    "storageId" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "expiration" INTEGER NOT NULL,
    "authKey" TEXT NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_upload_storage_path" ON "serverpod_cloud_storage_direct_upload" ("storageId", "path");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_future_call" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "time" INTEGER NOT NULL,
    "serializedObject" TEXT,
    "serverId" TEXT NOT NULL,
    "identifier" TEXT,
    "scheduling" TEXT
) STRICT;

-- Indexes
CREATE INDEX "serverpod_future_call_time_idx" ON "serverpod_future_call" ("time");
CREATE INDEX "serverpod_future_call_serverId_idx" ON "serverpod_future_call" ("serverId");
CREATE INDEX "serverpod_future_call_identifier_idx" ON "serverpod_future_call" ("identifier");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_future_call_claim" (
    "id" INTEGER PRIMARY KEY,
    "futureCallId" INTEGER,
    "lastHeartbeatTime" INTEGER NOT NULL,
    CONSTRAINT "serverpod_future_call_claim_fk_0" FOREIGN KEY ("futureCallId") REFERENCES "serverpod_future_call" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "future_call_unique_idx" ON "serverpod_future_call_claim" ("futureCallId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_health_connection_info" (
    "id" INTEGER PRIMARY KEY,
    "serverId" TEXT NOT NULL,
    "timestamp" INTEGER NOT NULL,
    "active" INTEGER NOT NULL,
    "closing" INTEGER NOT NULL,
    "idle" INTEGER NOT NULL,
    "granularity" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_connection_info_timestamp_idx" ON "serverpod_health_connection_info" ("timestamp", "serverId", "granularity");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_health_metric" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "serverId" TEXT NOT NULL,
    "timestamp" INTEGER NOT NULL,
    "isHealthy" INTEGER NOT NULL,
    "value" REAL NOT NULL,
    "granularity" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_metric_timestamp_idx" ON "serverpod_health_metric" ("timestamp", "serverId", "name", "granularity");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_log" (
    "id" INTEGER PRIMARY KEY,
    "sessionLogId" INTEGER NOT NULL,
    "messageId" INTEGER,
    "reference" TEXT,
    "serverId" TEXT NOT NULL,
    "time" INTEGER NOT NULL,
    "logLevel" INTEGER NOT NULL,
    "message" TEXT NOT NULL,
    "error" TEXT,
    "stackTrace" TEXT,
    "order" INTEGER NOT NULL,
    CONSTRAINT "serverpod_log_fk_0" FOREIGN KEY ("sessionLogId") REFERENCES "serverpod_session_log" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" ("sessionLogId", "order");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_message_log" (
    "id" INTEGER PRIMARY KEY,
    "sessionLogId" INTEGER NOT NULL,
    "serverId" TEXT NOT NULL,
    "messageId" INTEGER NOT NULL,
    "endpoint" TEXT NOT NULL,
    "messageName" TEXT NOT NULL,
    "duration" REAL NOT NULL,
    "error" TEXT,
    "stackTrace" TEXT,
    "slow" INTEGER NOT NULL,
    "order" INTEGER NOT NULL,
    CONSTRAINT "serverpod_message_log_fk_0" FOREIGN KEY ("sessionLogId") REFERENCES "serverpod_session_log" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE INDEX "serverpod_message_log_sessionLogId_idx" ON "serverpod_message_log" ("sessionLogId", "order");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_method" (
    "id" INTEGER PRIMARY KEY,
    "endpoint" TEXT NOT NULL,
    "method" TEXT NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_method_endpoint_method_idx" ON "serverpod_method" ("endpoint", "method");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_migrations" (
    "id" INTEGER PRIMARY KEY,
    "module" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "timestamp" INTEGER
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_migrations_ids" ON "serverpod_migrations" ("module");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_query_log" (
    "id" INTEGER PRIMARY KEY,
    "serverId" TEXT NOT NULL,
    "sessionLogId" INTEGER NOT NULL,
    "messageId" INTEGER,
    "query" TEXT NOT NULL,
    "duration" REAL NOT NULL,
    "numRows" INTEGER,
    "error" TEXT,
    "stackTrace" TEXT,
    "slow" INTEGER NOT NULL,
    "order" INTEGER NOT NULL,
    CONSTRAINT "serverpod_query_log_fk_0" FOREIGN KEY ("sessionLogId") REFERENCES "serverpod_session_log" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" ("sessionLogId", "order");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_readwrite_test" (
    "id" INTEGER PRIMARY KEY,
    "number" INTEGER NOT NULL
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_runtime_settings" (
    "id" INTEGER PRIMARY KEY,
    "logSettings" TEXT NOT NULL,
    "logSettingsOverrides" TEXT NOT NULL,
    "logServiceCalls" INTEGER NOT NULL,
    "logMalformedCalls" INTEGER NOT NULL
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_session_log" (
    "id" INTEGER PRIMARY KEY,
    "serverId" TEXT NOT NULL,
    "time" INTEGER NOT NULL,
    "module" TEXT,
    "endpoint" TEXT,
    "method" TEXT,
    "duration" REAL,
    "numQueries" INTEGER,
    "slow" INTEGER,
    "error" TEXT,
    "stackTrace" TEXT,
    "authenticatedUserId" INTEGER,
    "userId" TEXT,
    "isOpen" INTEGER,
    "touched" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE INDEX "serverpod_session_log_serverid_idx" ON "serverpod_session_log" ("serverId");
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" ("time");
CREATE INDEX "serverpod_session_log_touched_idx" ON "serverpod_session_log" ("touched");
CREATE INDEX "serverpod_session_log_isopen_idx" ON "serverpod_session_log" ("isOpen");

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
    ('serverpod_cloud_storage_direct_upload', 'expiration', 'timestampWithoutTimeZone', NULL),
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
    VALUES ('serverpod_offline_sync', '20260703114646971', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260703114646971', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260416151914983-insights-perf', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260416151914983-insights-perf', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
