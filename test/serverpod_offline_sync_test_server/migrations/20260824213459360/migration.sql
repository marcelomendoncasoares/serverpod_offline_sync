BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_address" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "street" TEXT NOT NULL,
    "inhabitantId" BLOB,
    CONSTRAINT "address_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "address_fk_1" FOREIGN KEY ("inhabitantId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_address" ("id", "scopeId", "street", "inhabitantId") SELECT "id", "scopeId", "street", "inhabitantId" FROM "address";
DROP TABLE "address";
ALTER TABLE "new_address" RENAME TO "address";

-- Indexes
CREATE UNIQUE INDEX "address__inhabitantId__unique_idx" ON "address" ("inhabitantId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_company" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "townId" BLOB NOT NULL DEFAULT (X'550e8400e29b41d4a716446655440000'),
    CONSTRAINT "company_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "company_fk_1" FOREIGN KEY ("townId") REFERENCES "town" ("id") ON DELETE SET DEFAULT ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_company" ("id", "scopeId", "name", "townId") SELECT "id", "scopeId", "name", "townId" FROM "company";
DROP TABLE "company";
ALTER TABLE "new_company" RENAME TO "company";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_cascade_middle" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "rootId" BLOB,
    CONSTRAINT "fk_chain_cascade_middle_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_cascade_middle_fk_1" FOREIGN KEY ("rootId") REFERENCES "fk_chain_root" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_cascade_middle" ("id", "scopeId", "name", "rootId") SELECT "id", "scopeId", "name", "rootId" FROM "fk_chain_cascade_middle";
DROP TABLE "fk_chain_cascade_middle";
ALTER TABLE "new_fk_chain_cascade_middle" RENAME TO "fk_chain_cascade_middle";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_middle_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "restrictBlockerId" BLOB,
    CONSTRAINT "fk_chain_middle_cascade_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_middle_cascade_child_fk_1" FOREIGN KEY ("restrictBlockerId") REFERENCES "fk_chain_restrict_blocker" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_middle_cascade_child" ("id", "scopeId", "name", "restrictBlockerId") SELECT "id", "scopeId", "name", "restrictBlockerId" FROM "fk_chain_middle_cascade_child";
DROP TABLE "fk_chain_middle_cascade_child";
ALTER TABLE "new_fk_chain_middle_cascade_child" RENAME TO "fk_chain_middle_cascade_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_middle_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "restrictBlockerId" BLOB,
    CONSTRAINT "fk_chain_middle_set_null_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_middle_set_null_child_fk_1" FOREIGN KEY ("restrictBlockerId") REFERENCES "fk_chain_restrict_blocker" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_middle_set_null_child" ("id", "scopeId", "name", "restrictBlockerId") SELECT "id", "scopeId", "name", "restrictBlockerId" FROM "fk_chain_middle_set_null_child";
DROP TABLE "fk_chain_middle_set_null_child";
ALTER TABLE "new_fk_chain_middle_set_null_child" RENAME TO "fk_chain_middle_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_restrict_blocker" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "cascadeMiddleId" BLOB,
    CONSTRAINT "fk_chain_restrict_blocker_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_restrict_blocker_fk_1" FOREIGN KEY ("cascadeMiddleId") REFERENCES "fk_chain_cascade_middle" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_restrict_blocker" ("id", "scopeId", "name", "cascadeMiddleId") SELECT "id", "scopeId", "name", "cascadeMiddleId" FROM "fk_chain_restrict_blocker";
DROP TABLE "fk_chain_restrict_blocker";
ALTER TABLE "new_fk_chain_restrict_blocker" RENAME TO "fk_chain_restrict_blocker";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_cascade_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_cascade_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_cascade_child" ("id", "scopeId", "name", "setNullMiddleId") SELECT "id", "scopeId", "name", "setNullMiddleId" FROM "fk_chain_set_null_cascade_child";
DROP TABLE "fk_chain_set_null_cascade_child";
ALTER TABLE "new_fk_chain_set_null_cascade_child" RENAME TO "fk_chain_set_null_cascade_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_middle" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "cascadeMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_middle_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_middle_fk_1" FOREIGN KEY ("cascadeMiddleId") REFERENCES "fk_chain_cascade_middle" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_middle" ("id", "scopeId", "name", "cascadeMiddleId") SELECT "id", "scopeId", "name", "cascadeMiddleId" FROM "fk_chain_set_null_middle";
DROP TABLE "fk_chain_set_null_middle";
ALTER TABLE "new_fk_chain_set_null_middle" RENAME TO "fk_chain_set_null_middle";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_restrict_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_restrict_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_restrict_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_restrict_child" ("id", "scopeId", "name", "setNullMiddleId") SELECT "id", "scopeId", "name", "setNullMiddleId" FROM "fk_chain_set_null_restrict_child";
DROP TABLE "fk_chain_set_null_restrict_child";
ALTER TABLE "new_fk_chain_set_null_restrict_child" RENAME TO "fk_chain_set_null_restrict_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_set_null_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_set_null_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_set_null_child" ("id", "scopeId", "name", "setNullMiddleId") SELECT "id", "scopeId", "name", "setNullMiddleId" FROM "fk_chain_set_null_set_null_child";
DROP TABLE "fk_chain_set_null_set_null_child";
ALTER TABLE "new_fk_chain_set_null_set_null_child" RENAME TO "fk_chain_set_null_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_organization" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "cityId" BLOB,
    CONSTRAINT "organization_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "organization_fk_1" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_organization" ("id", "scopeId", "name", "cityId") SELECT "id", "scopeId", "name", "cityId" FROM "organization";
DROP TABLE "organization";
ALTER TABLE "new_organization" RENAME TO "organization";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_person" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "surname" TEXT,
    "organizationId" BLOB,
    "oldCompanyId" BLOB,
    "cityId" BLOB,
    CONSTRAINT "person_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_1" FOREIGN KEY ("organizationId") REFERENCES "organization" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "person_fk_2" FOREIGN KEY ("oldCompanyId") REFERENCES "company" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_3" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_person" ("id", "scopeId", "name", "surname", "organizationId", "oldCompanyId") SELECT "id", "scopeId", "name", "surname", "organizationId", "oldCompanyId" FROM "person";
DROP TABLE "person";
ALTER TABLE "new_person" RENAME TO "person";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_required_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB NOT NULL,
    CONSTRAINT "required_set_null_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "required_set_null_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_required_set_null_child" ("id", "scopeId", "name", "parentId") SELECT "id", "scopeId", "name", "parentId" FROM "required_set_null_child";
DROP TABLE "required_set_null_child";
ALTER TABLE "new_required_set_null_child" RENAME TO "required_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_restrict_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "restrict_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "restrict_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_restrict_child" ("id", "scopeId", "name", "parentId") SELECT "id", "scopeId", "name", "parentId" FROM "restrict_child";
DROP TABLE "restrict_child";
ALTER TABLE "new_restrict_child" RENAME TO "restrict_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_town" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "cityId" BLOB,
    "mayorId" BLOB,
    CONSTRAINT "town_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "town_fk_1" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "town_fk_2" FOREIGN KEY ("mayorId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_town" ("id", "scopeId", "name", "cityId", "mayorId") SELECT "id", "scopeId", "name", "cityId", "mayorId" FROM "town";
DROP TABLE "town";
ALTER TABLE "new_town" RENAME TO "town";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "scopeId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_set_null_child_fk_0" FOREIGN KEY ("scopeId") REFERENCES "crdt_scopes" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_set_null_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_set_null_child" ("id", "scopeId", "name", "parentId") SELECT "id", "scopeId", "name", "parentId" FROM "unique_set_null_child";
DROP TABLE "unique_set_null_child";
ALTER TABLE "new_unique_set_null_child" RENAME TO "unique_set_null_child";

-- Indexes
CREATE UNIQUE INDEX "unique_set_null_child__parentId__unique_idx" ON "unique_set_null_child" ("parentId");

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
    ('unique_composite', 'id', 'uuid', NULL),
    ('unique_discriminator', 'id', 'uuid', NULL),
    ('unique_no_release', 'id', 'uuid', NULL),
    ('unique_set_null_child', 'id', 'uuid', NULL),
    ('unique_set_null_child', 'parentId', 'uuid', NULL),
    ('unique_uuid', 'id', 'uuid', NULL),
    ('unique_uuid', 'value', 'uuid', NULL),
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
    ('crdt_sync_integrity_violations', 'lastSeenAt', 'timestampWithoutTimeZone', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260824213459360', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824213459360', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260416151914983-insights-perf', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260416151914983-insights-perf', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260417182253191', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260417182253191', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260703114646971', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260703114646971', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
