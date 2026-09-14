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
-- ACTION ALTER TABLE
--
CREATE TABLE "new_address" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "street" TEXT NOT NULL,
    "inhabitantId" BLOB,
    CONSTRAINT "address_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "address_fk_1" FOREIGN KEY ("inhabitantId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_address" ("id", "street", "inhabitantId") SELECT "id", "street", "inhabitantId" FROM "address";
DROP TABLE "address";
ALTER TABLE "new_address" RENAME TO "address";

-- Indexes
CREATE UNIQUE INDEX "address__inhabitantId__unique_idx" ON "address" ("inhabitantId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_city" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    CONSTRAINT "city_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_city" ("id", "name") SELECT "id", "name" FROM "city";
DROP TABLE "city";
ALTER TABLE "new_city" RENAME TO "city";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_company" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "townId" BLOB NOT NULL DEFAULT (X'550e8400e29b41d4a716446655440000'),
    CONSTRAINT "company_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "company_fk_1" FOREIGN KEY ("townId") REFERENCES "town" ("id") ON DELETE SET DEFAULT ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_company" ("id", "name", "townId") SELECT "id", "name", "townId" FROM "company";
DROP TABLE "company";
ALTER TABLE "new_company" RENAME TO "company";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_cascade_middle" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "rootId" BLOB,
    CONSTRAINT "fk_chain_cascade_middle_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_cascade_middle_fk_1" FOREIGN KEY ("rootId") REFERENCES "fk_chain_root" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_cascade_middle" ("id", "name", "rootId") SELECT "id", "name", "rootId" FROM "fk_chain_cascade_middle";
DROP TABLE "fk_chain_cascade_middle";
ALTER TABLE "new_fk_chain_cascade_middle" RENAME TO "fk_chain_cascade_middle";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_middle_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "restrictBlockerId" BLOB,
    CONSTRAINT "fk_chain_middle_cascade_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_middle_cascade_child_fk_1" FOREIGN KEY ("restrictBlockerId") REFERENCES "fk_chain_restrict_blocker" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_middle_cascade_child" ("id", "name", "restrictBlockerId") SELECT "id", "name", "restrictBlockerId" FROM "fk_chain_middle_cascade_child";
DROP TABLE "fk_chain_middle_cascade_child";
ALTER TABLE "new_fk_chain_middle_cascade_child" RENAME TO "fk_chain_middle_cascade_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_middle_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "restrictBlockerId" BLOB,
    CONSTRAINT "fk_chain_middle_set_null_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_middle_set_null_child_fk_1" FOREIGN KEY ("restrictBlockerId") REFERENCES "fk_chain_restrict_blocker" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_middle_set_null_child" ("id", "name", "restrictBlockerId") SELECT "id", "name", "restrictBlockerId" FROM "fk_chain_middle_set_null_child";
DROP TABLE "fk_chain_middle_set_null_child";
ALTER TABLE "new_fk_chain_middle_set_null_child" RENAME TO "fk_chain_middle_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_restrict_blocker" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "cascadeMiddleId" BLOB,
    CONSTRAINT "fk_chain_restrict_blocker_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_restrict_blocker_fk_1" FOREIGN KEY ("cascadeMiddleId") REFERENCES "fk_chain_cascade_middle" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_restrict_blocker" ("id", "name", "cascadeMiddleId") SELECT "id", "name", "cascadeMiddleId" FROM "fk_chain_restrict_blocker";
DROP TABLE "fk_chain_restrict_blocker";
ALTER TABLE "new_fk_chain_restrict_blocker" RENAME TO "fk_chain_restrict_blocker";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_root" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    CONSTRAINT "fk_chain_root_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_fk_chain_root" ("id", "name") SELECT "id", "name" FROM "fk_chain_root";
DROP TABLE "fk_chain_root";
ALTER TABLE "new_fk_chain_root" RENAME TO "fk_chain_root";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_cascade_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_cascade_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_cascade_child" ("id", "name", "setNullMiddleId") SELECT "id", "name", "setNullMiddleId" FROM "fk_chain_set_null_cascade_child";
DROP TABLE "fk_chain_set_null_cascade_child";
ALTER TABLE "new_fk_chain_set_null_cascade_child" RENAME TO "fk_chain_set_null_cascade_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_middle" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "cascadeMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_middle_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_middle_fk_1" FOREIGN KEY ("cascadeMiddleId") REFERENCES "fk_chain_cascade_middle" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_middle" ("id", "name", "cascadeMiddleId") SELECT "id", "name", "cascadeMiddleId" FROM "fk_chain_set_null_middle";
DROP TABLE "fk_chain_set_null_middle";
ALTER TABLE "new_fk_chain_set_null_middle" RENAME TO "fk_chain_set_null_middle";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_restrict_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_restrict_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_restrict_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_restrict_child" ("id", "name", "setNullMiddleId") SELECT "id", "name", "setNullMiddleId" FROM "fk_chain_set_null_restrict_child";
DROP TABLE "fk_chain_set_null_restrict_child";
ALTER TABLE "new_fk_chain_set_null_restrict_child" RENAME TO "fk_chain_set_null_restrict_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_fk_chain_set_null_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "setNullMiddleId" BLOB,
    CONSTRAINT "fk_chain_set_null_set_null_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_chain_set_null_set_null_child_fk_1" FOREIGN KEY ("setNullMiddleId") REFERENCES "fk_chain_set_null_middle" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_fk_chain_set_null_set_null_child" ("id", "name", "setNullMiddleId") SELECT "id", "name", "setNullMiddleId" FROM "fk_chain_set_null_set_null_child";
DROP TABLE "fk_chain_set_null_set_null_child";
ALTER TABLE "new_fk_chain_set_null_set_null_child" RENAME TO "fk_chain_set_null_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_nullable_set_default_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "nullable_set_default_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "nullable_set_default_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE SET DEFAULT ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_nullable_set_default_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "nullable_set_default_child";
DROP TABLE "nullable_set_default_child";
ALTER TABLE "new_nullable_set_default_child" RENAME TO "nullable_set_default_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_organization" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "cityId" BLOB,
    CONSTRAINT "organization_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "organization_fk_1" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_organization" ("id", "name", "cityId") SELECT "id", "name", "cityId" FROM "organization";
DROP TABLE "organization";
ALTER TABLE "new_organization" RENAME TO "organization";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_person" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "surname" TEXT,
    "organizationId" BLOB,
    "oldCompanyId" BLOB,
    "cityId" BLOB,
    CONSTRAINT "person_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_1" FOREIGN KEY ("organizationId") REFERENCES "organization" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "person_fk_2" FOREIGN KEY ("oldCompanyId") REFERENCES "company" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_3" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_person" ("id", "name", "surname", "organizationId", "oldCompanyId", "cityId") SELECT "id", "name", "surname", "organizationId", "oldCompanyId", "cityId" FROM "person";
DROP TABLE "person";
ALTER TABLE "new_person" RENAME TO "person";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_required_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB NOT NULL,
    CONSTRAINT "required_cascade_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "required_cascade_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_required_cascade_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "required_cascade_child";
DROP TABLE "required_cascade_child";
ALTER TABLE "new_required_cascade_child" RENAME TO "required_cascade_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_required_no_action_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB NOT NULL,
    CONSTRAINT "required_no_action_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "required_no_action_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_required_no_action_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "required_no_action_child";
DROP TABLE "required_no_action_child";
ALTER TABLE "new_required_no_action_child" RENAME TO "required_no_action_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_required_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB NOT NULL,
    CONSTRAINT "required_set_null_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "required_set_null_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_required_set_null_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "required_set_null_child";
DROP TABLE "required_set_null_child";
ALTER TABLE "new_required_set_null_child" RENAME TO "required_set_null_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_restrict_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "restrict_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "restrict_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_restrict_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "restrict_child";
DROP TABLE "restrict_child";
ALTER TABLE "new_restrict_child" RENAME TO "restrict_child";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_town" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "cityId" BLOB,
    "mayorId" BLOB,
    CONSTRAINT "town_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "town_fk_1" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "town_fk_2" FOREIGN KEY ("mayorId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_town" ("id", "name", "cityId", "mayorId") SELECT "id", "name", "cityId", "mayorId" FROM "town";
DROP TABLE "town";
ALTER TABLE "new_town" RENAME TO "town";

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_types" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "aBool" INTEGER NOT NULL,
    "aDateTime" INTEGER NOT NULL,
    "aText" TEXT NOT NULL,
    "anInt" INTEGER NOT NULL,
    "anInt64" TEXT NOT NULL,
    "aReal" REAL NOT NULL,
    "aBlob" BLOB NOT NULL,
    "anEnum" INTEGER,
    "optionalText" TEXT,
    "optionalUuid" BLOB,
    CONSTRAINT "types_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_types" ("id", "aBool", "aDateTime", "aText", "anInt", "anInt64", "aReal", "aBlob", "anEnum", "optionalText", "optionalUuid") SELECT "id", "aBool", "aDateTime", "aText", "anInt", "anInt64", "aReal", "aBlob", "anEnum", "optionalText", "optionalUuid" FROM "types";
DROP TABLE "types";
ALTER TABLE "new_types" RENAME TO "types";

-- Indexes
CREATE INDEX "types_a_text_idx" ON "types" ("aText");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    CONSTRAINT "unique_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique" ("id", "name") SELECT "id", "name" FROM "unique";
DROP TABLE "unique";
ALTER TABLE "new_unique" RENAME TO "unique";

-- Indexes
CREATE UNIQUE INDEX "unique__spaceId__name__unique_idx" ON "unique" ("spaceId", "name");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_cascade_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_cascade_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_cascade_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_cascade_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "unique_cascade_child";
DROP TABLE "unique_cascade_child";
ALTER TABLE "new_unique_cascade_child" RENAME TO "unique_cascade_child";

-- Indexes
CREATE UNIQUE INDEX "unique_cascade_child__spaceId__name__unique_idx" ON "unique_cascade_child" ("spaceId", "name");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_cascade_reference" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_cascade_reference_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_cascade_reference_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_cascade_reference" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "unique_cascade_reference";
DROP TABLE "unique_cascade_reference";
ALTER TABLE "new_unique_cascade_reference" RENAME TO "unique_cascade_reference";

-- Indexes
CREATE UNIQUE INDEX "unique_cascade_reference__parentId__unique_idx" ON "unique_cascade_reference" ("parentId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_composite" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "scope" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    CONSTRAINT "unique_composite_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_composite" ("id", "scope", "value") SELECT "id", "scope", "value" FROM "unique_composite";
DROP TABLE "unique_composite";
ALTER TABLE "new_unique_composite" RENAME TO "unique_composite";

-- Indexes
CREATE UNIQUE INDEX "unique_composite__spaceId__scope__value__unique_idx" ON "unique_composite" ("spaceId", "scope", "value");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_discriminator" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "categoryId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    CONSTRAINT "unique_discriminator_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_discriminator" ("id", "categoryId", "name") SELECT "id", "categoryId", "name" FROM "unique_discriminator";
DROP TABLE "unique_discriminator";
ALTER TABLE "new_unique_discriminator" RENAME TO "unique_discriminator";

-- Indexes
CREATE UNIQUE INDEX "unique_discriminator__spaceId__categoryId__name__unique_idx" ON "unique_discriminator" ("spaceId", "categoryId", "name");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_fk_pair" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "leftId" BLOB,
    "rightId" BLOB,
    CONSTRAINT "unique_fk_pair_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_fk_pair_fk_1" FOREIGN KEY ("leftId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT "unique_fk_pair_fk_2" FOREIGN KEY ("rightId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_fk_pair" ("id", "name", "leftId", "rightId") SELECT "id", "name", "leftId", "rightId" FROM "unique_fk_pair";
DROP TABLE "unique_fk_pair";
ALTER TABLE "new_unique_fk_pair" RENAME TO "unique_fk_pair";

-- Indexes
CREATE UNIQUE INDEX "unique_fk_pair_parents" ON "unique_fk_pair" ("leftId", "rightId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_mixed_fk" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_mixed_fk_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_mixed_fk_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_mixed_fk" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "unique_mixed_fk";
DROP TABLE "unique_mixed_fk";
ALTER TABLE "new_unique_mixed_fk" RENAME TO "unique_mixed_fk";

-- Indexes
CREATE UNIQUE INDEX "unique_mixed_fk_name_parent" ON "unique_mixed_fk" ("spaceId", "name", "parentId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_no_release" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "categoryId" INTEGER NOT NULL,
    CONSTRAINT "unique_no_release_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_no_release" ("id", "categoryId") SELECT "id", "categoryId" FROM "unique_no_release";
DROP TABLE "unique_no_release";
ALTER TABLE "new_unique_no_release" RENAME TO "unique_no_release";

-- Indexes
CREATE UNIQUE INDEX "unique_no_release__spaceId__categoryId__unique_idx" ON "unique_no_release" ("spaceId", "categoryId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_nullable" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "value" INTEGER,
    CONSTRAINT "unique_nullable_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_nullable" ("id", "value") SELECT "id", "value" FROM "unique_nullable";
DROP TABLE "unique_nullable";
ALTER TABLE "new_unique_nullable" RENAME TO "unique_nullable";

-- Indexes
CREATE UNIQUE INDEX "unique_nullable__spaceId__value__unique_idx" ON "unique_nullable" ("spaceId", "value");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_overlapping" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "first" TEXT NOT NULL,
    "second" TEXT NOT NULL,
    "third" TEXT NOT NULL,
    CONSTRAINT "unique_overlapping_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_overlapping" ("id", "first", "second", "third") SELECT "id", "first", "second", "third" FROM "unique_overlapping";
DROP TABLE "unique_overlapping";
ALTER TABLE "new_unique_overlapping" RENAME TO "unique_overlapping";

-- Indexes
CREATE UNIQUE INDEX "unique_overlapping_first_second" ON "unique_overlapping" ("spaceId", "first", "second");

-- Indexes
CREATE UNIQUE INDEX "unique_overlapping_second_third" ON "unique_overlapping" ("spaceId", "second", "third");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_set_default_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB DEFAULT (X'550e8400e29b41d4a716446655440000'),
    CONSTRAINT "unique_set_default_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_set_default_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "town" ("id") ON DELETE SET DEFAULT ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_set_default_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "unique_set_default_child";
DROP TABLE "unique_set_default_child";
ALTER TABLE "new_unique_set_default_child" RENAME TO "unique_set_default_child";

-- Indexes
CREATE UNIQUE INDEX "unique_set_default_child__parentId__unique_idx" ON "unique_set_default_child" ("parentId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_set_null_child" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "name" TEXT NOT NULL,
    "parentId" BLOB,
    CONSTRAINT "unique_set_null_child_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "unique_set_null_child_fk_1" FOREIGN KEY ("parentId") REFERENCES "person" ("id") ON DELETE SET NULL ON UPDATE NO ACTION DEFERRABLE INITIALLY DEFERRED
) STRICT;

INSERT INTO "new_unique_set_null_child" ("id", "name", "parentId") SELECT "id", "name", "parentId" FROM "unique_set_null_child";
DROP TABLE "unique_set_null_child";
ALTER TABLE "new_unique_set_null_child" RENAME TO "unique_set_null_child";

-- Indexes
CREATE UNIQUE INDEX "unique_set_null_child__parentId__unique_idx" ON "unique_set_null_child" ("parentId");

--
-- ACTION ALTER TABLE
--
CREATE TABLE "new_unique_uuid" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "spaceId" INTEGER,
    "value" BLOB NOT NULL,
    CONSTRAINT "unique_uuid_fk_0" FOREIGN KEY ("spaceId") REFERENCES "offline_sync_spaces" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

INSERT INTO "new_unique_uuid" ("id", "value") SELECT "id", "value" FROM "unique_uuid";
DROP TABLE "unique_uuid";
ALTER TABLE "new_unique_uuid" RENAME TO "unique_uuid";

-- Indexes
CREATE UNIQUE INDEX "unique_uuid__spaceId__value__unique_idx" ON "unique_uuid" ("spaceId", "value");

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
    ('nullable_set_default_child', 'id', 'uuid', NULL),
    ('nullable_set_default_child', 'parentId', 'uuid', NULL),
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
    ('offline_sync_spaces', 'uuidSpaceId', 'uuid', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260914144112288', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260914144112288', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

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
    VALUES ('serverpod_offline_sync', '20260914143806119', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260914143806119', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
