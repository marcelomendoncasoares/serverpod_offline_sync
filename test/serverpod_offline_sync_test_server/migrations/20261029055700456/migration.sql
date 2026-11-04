BEGIN;

-- Preserve authored metadata identities and dependent attempted values.
CREATE TABLE "new_crdt_data_fields" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "spaceId" INTEGER NOT NULL,
    "syncRevision" INTEGER NOT NULL DEFAULT (0),
    "sourcePeerId" INTEGER,
    "rowId" INTEGER NOT NULL,
    "columnId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_fields_fk_0" FOREIGN KEY ("sourcePeerId") REFERENCES "offline_sync_peers" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_1" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_2" FOREIGN KEY ("columnId") REFERENCES "crdt_schema_columns" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_fields_fk_3" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_data_fields" ("id", "hlcDatetime", "hlcCounter", "rowId", "columnId", "nodeId", "spaceId") SELECT f."id", f."hlcDatetime", f."hlcCounter", f."rowId", f."columnId", f."nodeId", r."spaceId" FROM "crdt_data_fields" f JOIN "crdt_data_rows" r ON r."id" = f."rowId";
DROP TABLE "crdt_data_fields";
ALTER TABLE "new_crdt_data_fields" RENAME TO "crdt_data_fields";

-- Indexes
CREATE UNIQUE INDEX "crdt_data_fields_row_column_idx" ON "crdt_data_fields" ("rowId", "columnId");
CREATE INDEX "crdt_data_fields_space_revision_idx" ON "crdt_data_fields" ("spaceId", "syncRevision");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_crdt_data_rows" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "syncRevision" INTEGER NOT NULL DEFAULT (0),
    "sourcePeerId" INTEGER,
    "spaceId" INTEGER NOT NULL,
    "tblId" INTEGER NOT NULL,
    "uuidRowId" BLOB NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "visibility" INTEGER NOT NULL DEFAULT (0),
    CONSTRAINT "crdt_data_rows_fk_0" FOREIGN KEY ("sourcePeerId") REFERENCES "offline_sync_peers" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_1" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_2" FOREIGN KEY ("tblId") REFERENCES "crdt_schema_tables" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_rows_fk_3" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_data_rows" ("id", "hlcDatetime", "hlcCounter", "spaceId", "tblId", "uuidRowId", "nodeId", "visibility") SELECT "id", "hlcDatetime", "hlcCounter", "spaceId", "tblId", "uuidRowId", "nodeId", "visibility" FROM "crdt_data_rows";
DROP TABLE "crdt_data_rows";
ALTER TABLE "new_crdt_data_rows" RENAME TO "crdt_data_rows";

-- Indexes
CREATE UNIQUE INDEX "crdt_data_rows_space_tbl_row_idx" ON "crdt_data_rows" ("spaceId", "tblId", "uuidRowId");

-- Indexes
CREATE INDEX "crdt_data_rows_space_revision_idx" ON "crdt_data_rows" ("spaceId", "syncRevision");

-- Preserve authored metadata identities and dependent attempted values.
CREATE TABLE "new_crdt_data_tombstone" (
    "id" INTEGER PRIMARY KEY,
    "hlcDatetime" INTEGER NOT NULL,
    "hlcCounter" INTEGER NOT NULL,
    "spaceId" INTEGER NOT NULL,
    "syncRevision" INTEGER NOT NULL DEFAULT (0),
    "sourcePeerId" INTEGER,
    "rowId" INTEGER NOT NULL,
    "nodeId" INTEGER NOT NULL,
    "clFlag" INTEGER NOT NULL,
    "reason" INTEGER NOT NULL,
    CONSTRAINT "crdt_data_tombstone_fk_0" FOREIGN KEY ("sourcePeerId") REFERENCES "offline_sync_peers" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_tombstone_fk_1" FOREIGN KEY ("rowId") REFERENCES "crdt_data_rows" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "crdt_data_tombstone_fk_2" FOREIGN KEY ("nodeId") REFERENCES "crdt_nodes" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_crdt_data_tombstone" ("id", "hlcDatetime", "hlcCounter", "rowId", "nodeId", "clFlag", "reason", "spaceId") SELECT f."id", f."hlcDatetime", f."hlcCounter", f."rowId", f."nodeId", f."clFlag", f."reason", r."spaceId" FROM "crdt_data_tombstone" f JOIN "crdt_data_rows" r ON r."id" = f."rowId";
DROP TABLE "crdt_data_tombstone";
ALTER TABLE "new_crdt_data_tombstone" RENAME TO "crdt_data_tombstone";

-- Indexes
CREATE UNIQUE INDEX "crdt_data_tombstone_row_idx" ON "crdt_data_tombstone" ("rowId");
CREATE INDEX "crdt_data_tombstone_space_revision_idx" ON "crdt_data_tombstone" ("spaceId", "syncRevision");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_peer_checkpoints" (
    "id" INTEGER PRIMARY KEY,
    "spaceId" INTEGER NOT NULL,
    "peerId" INTEGER NOT NULL,
    "revision" INTEGER NOT NULL,
    CONSTRAINT "offline_sync_peer_checkpoints_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "offline_sync_peer_checkpoints_fk_1" FOREIGN KEY ("peerId") REFERENCES "offline_sync_peers" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "offline_sync_peer_checkpoint_identity_idx" ON "offline_sync_peer_checkpoints" ("spaceId", "peerId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_peers" (
    "id" INTEGER PRIMARY KEY,
    "userUuid" BLOB NOT NULL,
    "peerUuid" BLOB NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "offline_sync_peer_identity_idx" ON "offline_sync_peers" ("userUuid", "peerUuid");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "offline_sync_spaces" ADD COLUMN "syncRevision" INTEGER NOT NULL DEFAULT 0;

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
    ('required_cascade_child', 'id', 'uuid', NULL),
    ('required_cascade_child', 'parentId', 'uuid', NULL),
    ('required_no_action_child', 'id', 'uuid', NULL),
    ('required_no_action_child', 'parentId', 'uuid', NULL),
    ('restrict_child', 'id', 'uuid', NULL),
    ('restrict_child', 'parentId', 'uuid', NULL),
    ('shared_child', 'id', 'uuid', NULL),
    ('shared_child', 'parentId', 'uuid', NULL),
    ('shared_parent', 'id', 'uuid', NULL),
    ('town', 'id', 'uuid', NULL),
    ('town', 'cityId', 'uuid', NULL),
    ('town', 'mayorId', 'uuid', NULL),
    ('types', 'id', 'uuid', NULL),
    ('types', 'aBool', 'boolean', NULL),
    ('types', 'aDateTime', 'timestampWithoutTimeZone', NULL),
    ('types', 'optionalUuid', 'uuid', NULL),
    ('types', 'parentId', 'uuid', NULL),
    ('types', 'jsonDocument', 'json', NULL),
    ('types', 'jsonbDocument', 'jsonb', NULL),
    ('types', 'jsonbNumbers', 'jsonb', NULL),
    ('unique', 'id', 'uuid', NULL),
    ('unique_cascade_child', 'id', 'uuid', NULL),
    ('unique_cascade_child', 'parentId', 'uuid', NULL),
    ('unique_cascade_reference', 'id', 'uuid', NULL),
    ('unique_cascade_reference', 'parentId', 'uuid', NULL),
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
    ('unique_set_default_child', 'id', 'uuid', NULL),
    ('unique_set_default_child', 'parentId', 'uuid', NULL),
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
    ('offline_sync_peers', 'userUuid', 'uuid', NULL),
    ('offline_sync_peers', 'peerUuid', 'uuid', NULL),
    ('offline_sync_space_members', 'userUuid', 'uuid', NULL),
    ('offline_sync_space_nodes', 'lastReceivedHlc', 'jsonb', NULL),
    ('offline_sync_spaces', 'uuidSpaceId', 'uuid', NULL),
    ('offline_sync_spaces', 'lastHlc', 'jsonb', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20261029055700456', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261029055700456', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

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
    VALUES ('serverpod_auth_core', '20260924105232991', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20261029055509545', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261029055509545', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


-- Existing facts have unknown immediate provenance and must be visible from cursor zero.
UPDATE "crdt_data_rows" SET "syncRevision" = 1;
UPDATE "crdt_data_fields" SET "syncRevision" = 1;
UPDATE "crdt_data_tombstone" SET "syncRevision" = 1;
UPDATE "offline_sync_spaces" SET "syncRevision" = 1
WHERE EXISTS (SELECT 1 FROM "crdt_data_rows" r WHERE r."spaceId" = "offline_sync_spaces"."id");

COMMIT;
