BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "crdt_data_fields" DROP CONSTRAINT IF EXISTS "crdt_data_fields_fk_0";
ALTER TABLE "crdt_data_fields" DROP CONSTRAINT IF EXISTS "crdt_data_fields_fk_1";
ALTER TABLE "crdt_data_fields" DROP CONSTRAINT IF EXISTS "crdt_data_fields_fk_2";
ALTER TABLE "crdt_data_fields" ADD COLUMN "spaceId" bigint;
UPDATE "crdt_data_fields" AS fact SET "spaceId" = row."spaceId"
FROM "crdt_data_rows" AS row WHERE row."id" = fact."rowId";
ALTER TABLE "crdt_data_fields" ALTER COLUMN "spaceId" SET NOT NULL;
ALTER TABLE "crdt_data_fields" ADD COLUMN "syncRevision" bigint NOT NULL DEFAULT 0;
ALTER TABLE "crdt_data_fields" ADD COLUMN "sourcePeerId" bigint;
CREATE INDEX "crdt_data_fields_space_revision_idx" ON "crdt_data_fields" USING btree ("spaceId", "syncRevision");
--
-- ACTION ALTER TABLE
--
ALTER TABLE "crdt_data_rows" DROP CONSTRAINT IF EXISTS "crdt_data_rows_fk_0";
ALTER TABLE "crdt_data_rows" DROP CONSTRAINT IF EXISTS "crdt_data_rows_fk_1";
ALTER TABLE "crdt_data_rows" DROP CONSTRAINT IF EXISTS "crdt_data_rows_fk_2";
ALTER TABLE "crdt_data_rows" ADD COLUMN "syncRevision" bigint NOT NULL DEFAULT 0;
ALTER TABLE "crdt_data_rows" ADD COLUMN "sourcePeerId" bigint;
CREATE INDEX "crdt_data_rows_space_revision_idx" ON "crdt_data_rows" USING btree ("spaceId", "syncRevision");
--
-- ACTION ALTER TABLE
--
ALTER TABLE "crdt_data_tombstone" DROP CONSTRAINT IF EXISTS "crdt_data_tombstone_fk_0";
ALTER TABLE "crdt_data_tombstone" DROP CONSTRAINT IF EXISTS "crdt_data_tombstone_fk_1";
ALTER TABLE "crdt_data_tombstone" ADD COLUMN "spaceId" bigint;
UPDATE "crdt_data_tombstone" AS fact SET "spaceId" = row."spaceId"
FROM "crdt_data_rows" AS row WHERE row."id" = fact."rowId";
ALTER TABLE "crdt_data_tombstone" ALTER COLUMN "spaceId" SET NOT NULL;
ALTER TABLE "crdt_data_tombstone" ADD COLUMN "syncRevision" bigint NOT NULL DEFAULT 0;
ALTER TABLE "crdt_data_tombstone" ADD COLUMN "sourcePeerId" bigint;
CREATE INDEX "crdt_data_tombstone_space_revision_idx" ON "crdt_data_tombstone" USING btree ("spaceId", "syncRevision");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_peer_checkpoints" (
    "id" bigserial PRIMARY KEY,
    "spaceId" bigint NOT NULL,
    "peerId" bigint NOT NULL,
    "revision" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "offline_sync_peer_checkpoint_identity_idx" ON "offline_sync_peer_checkpoints" USING btree ("spaceId", "peerId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "offline_sync_peers" (
    "id" bigserial PRIMARY KEY,
    "userUuid" uuid NOT NULL,
    "peerUuid" uuid NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "offline_sync_peer_identity_idx" ON "offline_sync_peers" USING btree ("userUuid", "peerUuid");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "offline_sync_spaces" ADD COLUMN "syncRevision" bigint NOT NULL DEFAULT 0;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "crdt_data_fields"
    ADD CONSTRAINT "crdt_data_fields_fk_0"
    FOREIGN KEY("sourcePeerId")
    REFERENCES "offline_sync_peers"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_fields"
    ADD CONSTRAINT "crdt_data_fields_fk_1"
    FOREIGN KEY("rowId")
    REFERENCES "crdt_data_rows"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_fields"
    ADD CONSTRAINT "crdt_data_fields_fk_2"
    FOREIGN KEY("columnId")
    REFERENCES "crdt_schema_columns"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_fields"
    ADD CONSTRAINT "crdt_data_fields_fk_3"
    FOREIGN KEY("nodeId")
    REFERENCES "crdt_nodes"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "crdt_data_rows"
    ADD CONSTRAINT "crdt_data_rows_fk_3"
    FOREIGN KEY("nodeId")
    REFERENCES "crdt_nodes"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_rows"
    ADD CONSTRAINT "crdt_data_rows_fk_0"
    FOREIGN KEY("sourcePeerId")
    REFERENCES "offline_sync_peers"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_rows"
    ADD CONSTRAINT "crdt_data_rows_fk_1"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_rows"
    ADD CONSTRAINT "crdt_data_rows_fk_2"
    FOREIGN KEY("tblId")
    REFERENCES "crdt_schema_tables"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "crdt_data_tombstone"
    ADD CONSTRAINT "crdt_data_tombstone_fk_0"
    FOREIGN KEY("sourcePeerId")
    REFERENCES "offline_sync_peers"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_tombstone"
    ADD CONSTRAINT "crdt_data_tombstone_fk_1"
    FOREIGN KEY("rowId")
    REFERENCES "crdt_data_rows"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "crdt_data_tombstone"
    ADD CONSTRAINT "crdt_data_tombstone_fk_2"
    FOREIGN KEY("nodeId")
    REFERENCES "crdt_nodes"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "offline_sync_peer_checkpoints"
    ADD CONSTRAINT "offline_sync_peer_checkpoints_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "offline_sync_peer_checkpoints"
    ADD CONSTRAINT "offline_sync_peer_checkpoints_fk_1"
    FOREIGN KEY("peerId")
    REFERENCES "offline_sync_peers"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20261029055509545', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261029055509545', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


-- A fresh receiver starts at zero; all existing authored facts must be visible.
UPDATE "crdt_data_rows" SET "syncRevision" = 1;
UPDATE "crdt_data_fields" SET "syncRevision" = 1;
UPDATE "crdt_data_tombstone" SET "syncRevision" = 1;
UPDATE "offline_sync_spaces" SET "syncRevision" = 1
WHERE "id" IN (SELECT "spaceId" FROM "crdt_data_rows");

COMMIT;
