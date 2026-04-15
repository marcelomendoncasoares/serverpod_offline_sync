BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "address" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "street" TEXT NOT NULL,
    "inhabitantId" BLOB,
    CONSTRAINT "address_fk_0" FOREIGN KEY ("inhabitantId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "address__inhabitantId__unique_idx" ON "address" ("inhabitantId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "city" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "name" TEXT NOT NULL
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "company" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "name" TEXT NOT NULL,
    "townId" BLOB NOT NULL,
    CONSTRAINT "company_fk_0" FOREIGN KEY ("townId") REFERENCES "town" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "organization" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "name" TEXT NOT NULL,
    "cityId" BLOB,
    CONSTRAINT "organization_fk_0" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "person" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "name" TEXT NOT NULL,
    "organizationId" BLOB,
    "oldCompanyId" BLOB,
    "_cityCitizensCityId" BLOB,
    CONSTRAINT "person_fk_0" FOREIGN KEY ("organizationId") REFERENCES "organization" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_1" FOREIGN KEY ("oldCompanyId") REFERENCES "company" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_2" FOREIGN KEY ("_cityCitizensCityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "town" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "name" TEXT NOT NULL,
    "mayorId" BLOB,
    CONSTRAINT "town_fk_0" FOREIGN KEY ("mayorId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

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
    "identifier" TEXT
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
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" ("sessionLogId");

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
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" ("sessionLogId");

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
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_fields" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL,
    "datetime" INTEGER NOT NULL,
    "counter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "columnId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_fields_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_1" FOREIGN KEY ("columnId") REFERENCES "crdt_schema_columns" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_fields_row_column_idx" ON "crdt_data_fields" ("rowId", "columnId");

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
    "rowId" BLOB NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_rows_fk_0" FOREIGN KEY ("userId") REFERENCES "crdt_users" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_1" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_rows_user_tbl_row_idx" ON "crdt_data_rows" ("userId", "tblId", "rowId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_data_tombstone" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL,
    "datetime" INTEGER NOT NULL,
    "counter" INTEGER NOT NULL,
    "rowId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "isDeleted" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_tombstone_fk_0" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_tombstone_fk_1" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_data_tombstone_row_idx" ON "crdt_data_tombstone" ("rowId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_nodes" (
    "id" INTEGER PRIMARY KEY,
    "userId" INTEGER NOT NULL,
    "uuidNodeId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "lastSeenMigrationVersion" TEXT,
    "lastReceivedHlc" TEXT,
    CONSTRAINT "crdt_nodes_fk_0" FOREIGN KEY ("userId") REFERENCES "crdt_users" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_nodes_unique_idx" ON "crdt_nodes" ("uuidNodeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_schema_columns" (
    "id" INTEGER PRIMARY KEY,
    "tblId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    CONSTRAINT "crdt_schema_columns_fk_0" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
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
CREATE UNIQUE INDEX "crdt_schema_tables_idx" ON "crdt_schema_tables" ("name");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_users" (
    "id" INTEGER PRIMARY KEY,
    "uuidUserId" BLOB NOT NULL DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "currentNodeId" INTEGER,
    CONSTRAINT "crdt_users_fk_0" FOREIGN KEY ("currentNodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_users_idx" ON "crdt_users" ("uuidUserId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "crdt_workers" (
    "id" INTEGER PRIMARY KEY,
    "workerId" INTEGER NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "crdt_workers_unique_idx" ON "crdt_workers" ("workerId");

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
    ('address', 'street', 'text', NULL),
    ('address', 'inhabitantId', 'uuid', NULL),
    ('city', 'id', 'uuid', NULL),
    ('city', 'name', 'text', NULL),
    ('company', 'id', 'uuid', NULL),
    ('company', 'name', 'text', NULL),
    ('company', 'townId', 'uuid', NULL),
    ('organization', 'id', 'uuid', NULL),
    ('organization', 'name', 'text', NULL),
    ('organization', 'cityId', 'uuid', NULL),
    ('person', 'id', 'uuid', NULL),
    ('person', 'name', 'text', NULL),
    ('person', 'organizationId', 'uuid', NULL),
    ('person', 'oldCompanyId', 'uuid', NULL),
    ('person', '_cityCitizensCityId', 'uuid', NULL),
    ('town', 'id', 'uuid', NULL),
    ('town', 'name', 'text', NULL),
    ('town', 'mayorId', 'uuid', NULL),
    ('serverpod_cloud_storage', 'id', 'bigint', NULL),
    ('serverpod_cloud_storage', 'storageId', 'text', NULL),
    ('serverpod_cloud_storage', 'path', 'text', NULL),
    ('serverpod_cloud_storage', 'addedTime', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage', 'expiration', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage', 'byteData', 'bytea', NULL),
    ('serverpod_cloud_storage', 'verified', 'boolean', NULL),
    ('serverpod_cloud_storage_direct_upload', 'id', 'bigint', NULL),
    ('serverpod_cloud_storage_direct_upload', 'storageId', 'text', NULL),
    ('serverpod_cloud_storage_direct_upload', 'path', 'text', NULL),
    ('serverpod_cloud_storage_direct_upload', 'expiration', 'timestampWithoutTimeZone', NULL),
    ('serverpod_cloud_storage_direct_upload', 'authKey', 'text', NULL),
    ('serverpod_future_call', 'id', 'bigint', NULL),
    ('serverpod_future_call', 'name', 'text', NULL),
    ('serverpod_future_call', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_future_call', 'serializedObject', 'text', NULL),
    ('serverpod_future_call', 'serverId', 'text', NULL),
    ('serverpod_future_call', 'identifier', 'text', NULL),
    ('serverpod_future_call_claim', 'id', 'bigint', NULL),
    ('serverpod_future_call_claim', 'futureCallId', 'bigint', NULL),
    ('serverpod_future_call_claim', 'lastHeartbeatTime', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_connection_info', 'id', 'bigint', NULL),
    ('serverpod_health_connection_info', 'serverId', 'text', NULL),
    ('serverpod_health_connection_info', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_connection_info', 'active', 'bigint', NULL),
    ('serverpod_health_connection_info', 'closing', 'bigint', NULL),
    ('serverpod_health_connection_info', 'idle', 'bigint', NULL),
    ('serverpod_health_connection_info', 'granularity', 'bigint', NULL),
    ('serverpod_health_metric', 'id', 'bigint', NULL),
    ('serverpod_health_metric', 'name', 'text', NULL),
    ('serverpod_health_metric', 'serverId', 'text', NULL),
    ('serverpod_health_metric', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_health_metric', 'isHealthy', 'boolean', NULL),
    ('serverpod_health_metric', 'value', 'doublePrecision', NULL),
    ('serverpod_health_metric', 'granularity', 'bigint', NULL),
    ('serverpod_log', 'id', 'bigint', NULL),
    ('serverpod_log', 'sessionLogId', 'bigint', NULL),
    ('serverpod_log', 'messageId', 'bigint', NULL),
    ('serverpod_log', 'reference', 'text', NULL),
    ('serverpod_log', 'serverId', 'text', NULL),
    ('serverpod_log', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_log', 'logLevel', 'bigint', NULL),
    ('serverpod_log', 'message', 'text', NULL),
    ('serverpod_log', 'error', 'text', NULL),
    ('serverpod_log', 'stackTrace', 'text', NULL),
    ('serverpod_log', 'order', 'bigint', NULL),
    ('serverpod_message_log', 'id', 'bigint', NULL),
    ('serverpod_message_log', 'sessionLogId', 'bigint', NULL),
    ('serverpod_message_log', 'serverId', 'text', NULL),
    ('serverpod_message_log', 'messageId', 'bigint', NULL),
    ('serverpod_message_log', 'endpoint', 'text', NULL),
    ('serverpod_message_log', 'messageName', 'text', NULL),
    ('serverpod_message_log', 'duration', 'doublePrecision', NULL),
    ('serverpod_message_log', 'error', 'text', NULL),
    ('serverpod_message_log', 'stackTrace', 'text', NULL),
    ('serverpod_message_log', 'slow', 'boolean', NULL),
    ('serverpod_message_log', 'order', 'bigint', NULL),
    ('serverpod_method', 'id', 'bigint', NULL),
    ('serverpod_method', 'endpoint', 'text', NULL),
    ('serverpod_method', 'method', 'text', NULL),
    ('serverpod_migrations', 'id', 'bigint', NULL),
    ('serverpod_migrations', 'module', 'text', NULL),
    ('serverpod_migrations', 'version', 'text', NULL),
    ('serverpod_migrations', 'timestamp', 'timestampWithoutTimeZone', NULL),
    ('serverpod_query_log', 'id', 'bigint', NULL),
    ('serverpod_query_log', 'serverId', 'text', NULL),
    ('serverpod_query_log', 'sessionLogId', 'bigint', NULL),
    ('serverpod_query_log', 'messageId', 'bigint', NULL),
    ('serverpod_query_log', 'query', 'text', NULL),
    ('serverpod_query_log', 'duration', 'doublePrecision', NULL),
    ('serverpod_query_log', 'numRows', 'bigint', NULL),
    ('serverpod_query_log', 'error', 'text', NULL),
    ('serverpod_query_log', 'stackTrace', 'text', NULL),
    ('serverpod_query_log', 'slow', 'boolean', NULL),
    ('serverpod_query_log', 'order', 'bigint', NULL),
    ('serverpod_readwrite_test', 'id', 'bigint', NULL),
    ('serverpod_readwrite_test', 'number', 'bigint', NULL),
    ('serverpod_runtime_settings', 'id', 'bigint', NULL),
    ('serverpod_runtime_settings', 'logSettings', 'json', NULL),
    ('serverpod_runtime_settings', 'logSettingsOverrides', 'json', NULL),
    ('serverpod_runtime_settings', 'logServiceCalls', 'boolean', NULL),
    ('serverpod_runtime_settings', 'logMalformedCalls', 'boolean', NULL),
    ('serverpod_session_log', 'id', 'bigint', NULL),
    ('serverpod_session_log', 'serverId', 'text', NULL),
    ('serverpod_session_log', 'time', 'timestampWithoutTimeZone', NULL),
    ('serverpod_session_log', 'module', 'text', NULL),
    ('serverpod_session_log', 'endpoint', 'text', NULL),
    ('serverpod_session_log', 'method', 'text', NULL),
    ('serverpod_session_log', 'duration', 'doublePrecision', NULL),
    ('serverpod_session_log', 'numQueries', 'bigint', NULL),
    ('serverpod_session_log', 'slow', 'boolean', NULL),
    ('serverpod_session_log', 'error', 'text', NULL),
    ('serverpod_session_log', 'stackTrace', 'text', NULL),
    ('serverpod_session_log', 'authenticatedUserId', 'bigint', NULL),
    ('serverpod_session_log', 'userId', 'text', NULL),
    ('serverpod_session_log', 'isOpen', 'boolean', NULL),
    ('serverpod_session_log', 'touched', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_fields', 'id', 'bigint', NULL),
    ('crdt_data_fields', 'workerId', 'bigint', NULL),
    ('crdt_data_fields', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_fields', 'counter', 'bigint', NULL),
    ('crdt_data_fields', 'rowId', 'bigint', NULL),
    ('crdt_data_fields', 'columnId', 'bigint', NULL),
    ('crdt_data_fields', 'nodeId', 'bigint', NULL),
    ('crdt_data_rows', 'id', 'bigint', NULL),
    ('crdt_data_rows', 'workerId', 'bigint', NULL),
    ('crdt_data_rows', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'counter', 'bigint', NULL),
    ('crdt_data_rows', 'userId', 'bigint', NULL),
    ('crdt_data_rows', 'tblId', 'bigint', NULL),
    ('crdt_data_rows', 'rowId', 'uuid', NULL),
    ('crdt_data_rows', 'nodeId', 'bigint', NULL),
    ('crdt_data_tombstone', 'id', 'bigint', NULL),
    ('crdt_data_tombstone', 'workerId', 'bigint', NULL),
    ('crdt_data_tombstone', 'datetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_tombstone', 'counter', 'bigint', NULL),
    ('crdt_data_tombstone', 'rowId', 'bigint', NULL),
    ('crdt_data_tombstone', 'nodeId', 'bigint', NULL),
    ('crdt_data_tombstone', 'isDeleted', 'boolean', NULL),
    ('crdt_nodes', 'id', 'bigint', NULL),
    ('crdt_nodes', 'userId', 'bigint', NULL),
    ('crdt_nodes', 'uuidNodeId', 'uuid', NULL),
    ('crdt_nodes', 'lastSeenMigrationVersion', 'text', NULL),
    ('crdt_nodes', 'lastReceivedHlc', 'json', NULL),
    ('crdt_schema_columns', 'id', 'bigint', NULL),
    ('crdt_schema_columns', 'tblId', 'bigint', NULL),
    ('crdt_schema_columns', 'name', 'text', NULL),
    ('crdt_schema_tables', 'id', 'bigint', NULL),
    ('crdt_schema_tables', 'name', 'text', NULL),
    ('crdt_users', 'id', 'bigint', NULL),
    ('crdt_users', 'uuidUserId', 'uuid', NULL),
    ('crdt_users', 'currentNodeId', 'bigint', NULL),
    ('crdt_workers', 'id', 'bigint', NULL),
    ('crdt_workers', 'workerId', 'bigint', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260415031804313', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260415031804313', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260324085808546', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085808546', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260415022807074', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260415022807074', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
