BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "unique_fk_pair" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "leftId" BLOB,
    "rightId" BLOB,
    CONSTRAINT "unique_fk_pair_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_fk_pair_fk_1" FOREIGN KEY ("leftId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "unique_fk_pair_fk_2" FOREIGN KEY ("rightId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "unique_fk_pair_parents" ON "unique_fk_pair" ("leftId", "rightId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "unique_mixed_fk" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_mixed_fk_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_mixed_fk_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "unique_mixed_fk_name_parent" ON "unique_mixed_fk" ("scopeId", "name", "parentId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "unique_nullable" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "value" INTEGER,
    CONSTRAINT "unique_nullable_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "unique_nullable__scopeId__value__unique_idx" ON "unique_nullable" ("scopeId", "value");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "unique_overlapping" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "first" TEXT NOT NULL,
    "second" TEXT NOT NULL,
    "third" TEXT NOT NULL,
    CONSTRAINT "unique_overlapping_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "unique_overlapping_first_second" ON "unique_overlapping" ("scopeId", "first", "second");
CREATE UNIQUE INDEX "unique_overlapping_second_third" ON "unique_overlapping" ("scopeId", "second", "third");

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
    ('fk_chain_cascade_middle', 'id', 'uuid', NULL),
    ('fk_chain_cascade_middle', 'rootId', 'uuid', NULL),
    ('fk_chain_middle_cascade_child', 'id', 'uuid', NULL),
    ('fk_chain_middle_cascade_child', 'restrictBlockerId', 'uuid', NULL),
    ('fk_chain_middle_set_null_child', 'id', 'uuid', NULL),
    ('fk_chain_middle_set_null_child', 'restrictBlockerId', 'uuid', NULL),
    ('fk_chain_restrict_blocker', 'id', 'uuid', NULL),
    ('fk_chain_restrict_blocker', 'cascadeMiddleId', 'uuid', NULL),
    ('fk_chain_root', 'id', 'uuid', NULL),
    ('fk_chain_set_null_cascade_child', 'id', 'uuid', NULL),
    ('fk_chain_set_null_cascade_child', 'setNullMiddleId', 'uuid', NULL),
    ('fk_chain_set_null_middle', 'id', 'uuid', NULL),
    ('fk_chain_set_null_middle', 'cascadeMiddleId', 'uuid', NULL),
    ('fk_chain_set_null_restrict_child', 'id', 'uuid', NULL),
    ('fk_chain_set_null_restrict_child', 'setNullMiddleId', 'uuid', NULL),
    ('fk_chain_set_null_set_null_child', 'id', 'uuid', NULL),
    ('fk_chain_set_null_set_null_child', 'setNullMiddleId', 'uuid', NULL),
    ('organization', 'id', 'uuid', NULL),
    ('organization', 'cityId', 'uuid', NULL),
    ('person', 'id', 'uuid', NULL),
    ('person', 'organizationId', 'uuid', NULL),
    ('person', 'oldCompanyId', 'uuid', NULL),
    ('person', 'cityId', 'uuid', NULL),
    ('required_set_null_child', 'id', 'uuid', NULL),
    ('required_set_null_child', 'parentId', 'uuid', NULL),
    ('restrict_child', 'id', 'uuid', NULL),
    ('restrict_child', 'parentId', 'uuid', NULL),
    ('town', 'id', 'uuid', NULL),
    ('town', 'cityId', 'uuid', NULL),
    ('town', 'mayorId', 'uuid', NULL),
    ('types', 'id', 'uuid', NULL),
    ('types', 'aBool', 'boolean', NULL),
    ('types', 'aDateTime', 'timestampWithoutTimeZone', NULL),
    ('types', 'optionalUuid', 'uuid', NULL),
    ('unique', 'id', 'uuid', NULL),
    ('unique_cascade_child', 'id', 'uuid', NULL),
    ('unique_cascade_child', 'parentId', 'uuid', NULL),
    ('unique_composite', 'id', 'uuid', NULL),
    ('unique_discriminator', 'id', 'uuid', NULL),
    ('unique_fk_pair', 'id', 'uuid', NULL),
    ('unique_fk_pair', 'leftId', 'uuid', NULL),
    ('unique_fk_pair', 'rightId', 'uuid', NULL),
    ('unique_mixed_fk', 'id', 'uuid', NULL),
    ('unique_mixed_fk', 'parentId', 'uuid', NULL),
    ('unique_no_release', 'id', 'uuid', NULL),
    ('unique_nullable', 'id', 'uuid', NULL),
    ('unique_overlapping', 'id', 'uuid', NULL),
    ('unique_set_null_child', 'id', 'uuid', NULL),
    ('unique_set_null_child', 'parentId', 'uuid', NULL),
    ('unique_uuid', 'id', 'uuid', NULL),
    ('unique_uuid', 'value', 'uuid', NULL),
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
    ('serverpod_session_log', 'touched', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'id', 'uuid', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'lastUpdatedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_profile', 'id', 'uuid', NULL),
    ('serverpod_auth_core_profile', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_profile', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_profile', 'imageId', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'id', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'userProfileId', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'id', 'uuid', NULL),
    ('serverpod_auth_core_session', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_session', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_session', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'lastUsedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'expiresAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_user', 'id', 'uuid', NULL),
    ('serverpod_auth_core_user', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_user', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_user', 'blocked', 'boolean', NULL),
    ('crdt_data_attempted_value', 'value', 'jsonb', NULL),
    ('crdt_data_fields', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_data_rows', 'uuidRowId', 'uuid', NULL),
    ('crdt_data_tombstone', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_nodes', 'uuidNodeId', 'uuid', NULL),
    ('crdt_nodes', 'lastHlc', 'jsonb', NULL),
    ('crdt_schema_columns', 'isNullable', 'boolean', NULL),
    ('crdt_scope_members', 'userUuid', 'uuid', NULL),
    ('crdt_scope_nodes', 'lastReceivedHlc', 'jsonb', NULL),
    ('crdt_scopes', 'uuidScopeId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'uuidRowId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'ownerScopeUuid', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'incomingScopeUuid', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'uuidNodeId', 'uuid', NULL),
    ('crdt_sync_integrity_violations', 'hlcDatetime', 'timestampWithoutTimeZone', NULL),
    ('crdt_sync_integrity_violations', 'firstSeenAt', 'timestampWithoutTimeZone', NULL),
    ('crdt_sync_integrity_violations', 'lastSeenAt', 'timestampWithoutTimeZone', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260907165715131', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260907165715131', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260824182354731', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182354731', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260902195732182', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260902195732182', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
