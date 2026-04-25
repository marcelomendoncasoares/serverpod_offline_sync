BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "serverpod_future_call" ADD COLUMN "scheduling" TEXT;
--
-- ACTION ALTER TABLE
--
DROP INDEX "serverpod_log_sessionLogId_idx";
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" ("sessionLogId", "order");
--
-- ACTION ALTER TABLE
--
CREATE INDEX "serverpod_message_log_sessionLogId_idx" ON "serverpod_message_log" ("sessionLogId", "order");
--
-- ACTION ALTER TABLE
--
DROP INDEX "serverpod_query_log_sessionLogId_idx";
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" ("sessionLogId", "order");
--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_data_fields" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL,
    "datetime" INTEGER NOT NULL,
    "counter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "columnId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_fields_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_1" FOREIGN KEY ("columnId") REFERENCES "crdt_schema_columns" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_data_fields" ("id", "workerId", "datetime", "counter", "rowId", "columnId", "nodeId") SELECT "id", "workerId", "datetime", "counter", "rowId", "columnId", "nodeId" FROM "crdt_data_fields";
DROP TABLE "crdt_data_fields";
ALTER TABLE "new_crdt_data_fields" RENAME TO "crdt_data_fields";

-- Indexes
CREATE UNIQUE INDEX "crdt_data_fields_row_column_idx" ON "crdt_data_fields" ("rowId", "columnId");

--
-- ACTION DROP TABLE
--
DROP TABLE "crdt_data_rows";

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_rows" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL,
    "datetime" INTEGER NOT NULL,
    "counter" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "tblId" INTEGER NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_rows_fk_0" FOREIGN KEY ("userId") REFERENCES "crdt_users" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_1" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_rows_user_tbl_row_idx" ON "crdt_data_rows" ("userId", "tblId", "uuidRowId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_data_tombstone" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL,
    "datetime" INTEGER NOT NULL,
    "counter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "isDeleted" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_tombstone_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_tombstone_fk_1" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_data_tombstone" ("id", "workerId", "datetime", "counter", "rowId", "nodeId", "isDeleted") SELECT "id", "workerId", "datetime", "counter", "rowId", "nodeId", "isDeleted" FROM "crdt_data_tombstone";
DROP TABLE "crdt_data_tombstone";
ALTER TABLE "new_crdt_data_tombstone" RENAME TO "crdt_data_tombstone";

-- Indexes
CREATE UNIQUE INDEX "crdt_data_tombstone_row_idx" ON "crdt_data_tombstone" ("rowId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_nodes" (
    "id" INTEGER PRIMARY KEY,
    "userId" INTEGER NOT NULL,
    "uuidNodeId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "lastSeenMigrationVersion" TEXT,
    "lastReceivedHlc" TEXT,
    CONSTRAINT "crdt_nodes_fk_0" FOREIGN KEY ("userId") REFERENCES "crdt_users" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_nodes" ("id", "userId", "uuidNodeId", "lastSeenMigrationVersion", "lastReceivedHlc") SELECT "id", "userId", "uuidNodeId", "lastSeenMigrationVersion", "lastReceivedHlc" FROM "crdt_nodes";
DROP TABLE "crdt_nodes";
ALTER TABLE "new_crdt_nodes" RENAME TO "crdt_nodes";

-- Indexes
CREATE UNIQUE INDEX "crdt_nodes__uuidNodeId__unique_idx" ON "crdt_nodes" ("uuidNodeId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_schema_columns" (
    "id" INTEGER PRIMARY KEY,
    "tblId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    CONSTRAINT "crdt_schema_columns_fk_0" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_schema_columns" ("id", "tblId", "name") SELECT "id", "tblId", "name" FROM "crdt_schema_columns";
DROP TABLE "crdt_schema_columns";
ALTER TABLE "new_crdt_schema_columns" RENAME TO "crdt_schema_columns";

-- Indexes
CREATE UNIQUE INDEX "crdt_schema_columns_table_column_idx" ON "crdt_schema_columns" ("tblId", "name");

--
-- ACTION ALTER TABLE
--
DROP INDEX "crdt_schema_tables_idx";
CREATE UNIQUE INDEX "crdt_schema_tables__name__unique_idx" ON "crdt_schema_tables" ("name");
--
-- ACTION ALTER TABLE
--
DROP INDEX "crdt_users_idx";
CREATE UNIQUE INDEX "crdt_users__uuidUserId__unique_idx" ON "crdt_users" ("uuidUserId");
--
-- ACTION ALTER TABLE
--
DROP INDEX "crdt_workers_unique_idx";
CREATE UNIQUE INDEX "crdt_workers__workerId__unique_idx" ON "crdt_workers" ("workerId");
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
    ('address', 'id', 'uuid', NULL),
    ('address', 'inhabitantId', 'uuid', NULL),
    ('city', 'id', 'uuid', NULL),
    ('company', 'id', 'uuid', NULL),
    ('company', 'townId', 'uuid', NULL),
    ('organization', 'id', 'uuid', NULL),
    ('organization', 'cityId', 'uuid', NULL),
    ('person', 'id', 'uuid', NULL),
    ('person', 'organizationId', 'uuid', NULL),
    ('person', 'oldCompanyId', 'uuid', NULL),
    ('person', '_cityCitizensCityId', 'uuid', NULL),
    ('town', 'id', 'uuid', NULL),
    ('town', 'mayorId', 'uuid', NULL),
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
    ('serverpod_session_log', 'touched', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_fields', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'uuidRowId', 'uuid', NULL),
    ('crdt_data_tombstone', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_tombstone', 'isDeleted', 'boolean', NULL),
    ('crdt_nodes', 'uuidNodeId', 'uuid', NULL),
    ('crdt_nodes', 'lastReceivedHlc', 'json', NULL),
    ('crdt_users', 'uuidUserId', 'uuid', NULL),

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260425022441248', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260425022441248', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260416151914983-insights-perf', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260416151914983-insights-perf', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260420011738588', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260420011738588', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
