BEGIN;

--
-- Class Address as table address
--
CREATE TABLE "address" (
    "id" INTEGER PRIMARY KEY,
    "street" TEXT NOT NULL,
    "inhabitantId" INTEGER,
    CONSTRAINT "address_fk_0" FOREIGN KEY ("inhabitantId") REFERENCES "person" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "address__inhabitantId__unique_idx" ON "address" ("inhabitantId");


--
-- Class City as table city
--
CREATE TABLE "city" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL
) STRICT;


--
-- Class Company as table company
--
CREATE TABLE "company" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "townId" INTEGER NOT NULL,
    CONSTRAINT "company_fk_0" FOREIGN KEY ("townId") REFERENCES "town" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;


--
-- Class Organization as table organization
--
CREATE TABLE "organization" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "cityId" INTEGER,
    CONSTRAINT "organization_fk_0" FOREIGN KEY ("cityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;


--
-- Class Person as table person
--
CREATE TABLE "person" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "organizationId" INTEGER,
    "oldCompanyId" INTEGER,
    "_cityCitizensCityId" INTEGER,
    CONSTRAINT "person_fk_0" FOREIGN KEY ("organizationId") REFERENCES "organization" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_1" FOREIGN KEY ("oldCompanyId") REFERENCES "company" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "person_fk_2" FOREIGN KEY ("_cityCitizensCityId") REFERENCES "city" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;


--
-- Class Town as table town
--
CREATE TABLE "town" (
    "id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL,
    "mayorId" INTEGER,
    CONSTRAINT "town_fk_0" FOREIGN KEY ("mayorId") REFERENCES "person" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;


--
-- Class CloudStorageEntry as table serverpod_cloud_storage
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
-- Class CloudStorageDirectUploadEntry as table serverpod_cloud_storage_direct_upload
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
-- Class FutureCallEntry as table serverpod_future_call
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
-- Class FutureCallClaimEntry as table serverpod_future_call_claim
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
-- Class ServerHealthConnectionInfo as table serverpod_health_connection_info
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
-- Class ServerHealthMetric as table serverpod_health_metric
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
-- Class LogEntry as table serverpod_log
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
-- Class MessageLogEntry as table serverpod_message_log
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
-- Class MethodInfo as table serverpod_method
--
CREATE TABLE "serverpod_method" (
    "id" INTEGER PRIMARY KEY,
    "endpoint" TEXT NOT NULL,
    "method" TEXT NOT NULL
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_method_endpoint_method_idx" ON "serverpod_method" ("endpoint", "method");


--
-- Class DatabaseMigrationVersion as table serverpod_migrations
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
-- Class QueryLogEntry as table serverpod_query_log
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
-- Class ReadWriteTestEntry as table serverpod_readwrite_test
--
CREATE TABLE "serverpod_readwrite_test" (
    "id" INTEGER PRIMARY KEY,
    "number" INTEGER NOT NULL
) STRICT;


--
-- Class RuntimeSettings as table serverpod_runtime_settings
--
CREATE TABLE "serverpod_runtime_settings" (
    "id" INTEGER PRIMARY KEY,
    "logSettings" TEXT NOT NULL,
    "logSettingsOverrides" TEXT NOT NULL,
    "logServiceCalls" INTEGER NOT NULL,
    "logMalformedCalls" INTEGER NOT NULL
) STRICT;


--
-- Class SessionLogEntry as table serverpod_session_log
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
-- Class AnonymousAccount as table serverpod_auth_idp_anonymous_account
--
CREATE TABLE "serverpod_auth_idp_anonymous_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL,
    CONSTRAINT "serverpod_auth_idp_anonymous_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;


--
-- Class AppleAccount as table serverpod_auth_idp_apple_account
--
CREATE TABLE "serverpod_auth_idp_apple_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "userIdentifier" TEXT NOT NULL,
    "refreshToken" TEXT NOT NULL,
    "refreshTokenRequestedWithBundleIdentifier" INTEGER NOT NULL,
    "lastRefreshedAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "authUserId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL,
    "email" TEXT,
    "isEmailVerified" INTEGER,
    "isPrivateEmail" INTEGER,
    "firstName" TEXT,
    "lastName" TEXT,
    CONSTRAINT "serverpod_auth_idp_apple_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_apple_account_identifier" ON "serverpod_auth_idp_apple_account" ("userIdentifier");


--
-- Class EmailAccount as table serverpod_auth_idp_email_account
--
CREATE TABLE "serverpod_auth_idp_email_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    CONSTRAINT "serverpod_auth_idp_email_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_idp_email_account_email" ON "serverpod_auth_idp_email_account" ("email");


--
-- Class EmailAccountPasswordResetRequest as table serverpod_auth_idp_email_account_password_reset_request
--
CREATE TABLE "serverpod_auth_idp_email_account_password_reset_request" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "emailAccountId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "challengeId" BLOB NOT NULL,
    "setPasswordChallengeId" BLOB,
    CONSTRAINT "serverpod_auth_idp_email_account_password_reset_request_fk_0" FOREIGN KEY ("emailAccountId") REFERENCES "serverpod_auth_idp_email_account" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "serverpod_auth_idp_email_account_password_reset_request_fk_1" FOREIGN KEY ("challengeId") REFERENCES "serverpod_auth_idp_secret_challenge" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "serverpod_auth_idp_email_account_password_reset_request_fk_2" FOREIGN KEY ("setPasswordChallengeId") REFERENCES "serverpod_auth_idp_secret_challenge" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;


--
-- Class EmailAccountRequest as table serverpod_auth_idp_email_account_request
--
CREATE TABLE "serverpod_auth_idp_email_account_request" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "email" TEXT NOT NULL,
    "challengeId" BLOB NOT NULL,
    "createAccountChallengeId" BLOB,
    CONSTRAINT "serverpod_auth_idp_email_account_request_fk_0" FOREIGN KEY ("challengeId") REFERENCES "serverpod_auth_idp_secret_challenge" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "serverpod_auth_idp_email_account_request_fk_1" FOREIGN KEY ("createAccountChallengeId") REFERENCES "serverpod_auth_idp_secret_challenge" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_idp_email_account_request_email" ON "serverpod_auth_idp_email_account_request" ("email");


--
-- Class FacebookAccount as table serverpod_auth_idp_facebook_account
--
CREATE TABLE "serverpod_auth_idp_facebook_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL,
    "userIdentifier" TEXT NOT NULL,
    "email" TEXT,
    "fullName" TEXT,
    "firstName" TEXT,
    "lastName" TEXT,
    CONSTRAINT "serverpod_auth_idp_facebook_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_facebook_account_user_identifier" ON "serverpod_auth_idp_facebook_account" ("userIdentifier");


--
-- Class FirebaseAccount as table serverpod_auth_idp_firebase_account
--
CREATE TABLE "serverpod_auth_idp_firebase_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "created" INTEGER NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "userIdentifier" TEXT NOT NULL,
    CONSTRAINT "serverpod_auth_idp_firebase_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_firebase_account_user_identifier" ON "serverpod_auth_idp_firebase_account" ("userIdentifier");


--
-- Class GitHubAccount as table serverpod_auth_idp_github_account
--
CREATE TABLE "serverpod_auth_idp_github_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "userIdentifier" TEXT NOT NULL,
    "email" TEXT,
    "created" INTEGER NOT NULL,
    CONSTRAINT "serverpod_auth_idp_github_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_github_account_user_identifier" ON "serverpod_auth_idp_github_account" ("userIdentifier");


--
-- Class GoogleAccount as table serverpod_auth_idp_google_account
--
CREATE TABLE "serverpod_auth_idp_google_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "created" INTEGER NOT NULL,
    "email" TEXT NOT NULL,
    "userIdentifier" TEXT NOT NULL,
    CONSTRAINT "serverpod_auth_idp_google_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_google_account_user_identifier" ON "serverpod_auth_idp_google_account" ("userIdentifier");


--
-- Class MicrosoftAccount as table serverpod_auth_idp_microsoft_account
--
CREATE TABLE "serverpod_auth_idp_microsoft_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "userIdentifier" TEXT NOT NULL,
    "email" TEXT,
    "created" INTEGER NOT NULL,
    CONSTRAINT "serverpod_auth_idp_microsoft_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_microsoft_account_user_identifier" ON "serverpod_auth_idp_microsoft_account" ("userIdentifier");


--
-- Class PasskeyAccount as table serverpod_auth_idp_passkey_account
--
CREATE TABLE "serverpod_auth_idp_passkey_account" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL,
    "keyId" BLOB NOT NULL,
    "keyIdBase64" TEXT NOT NULL,
    "clientDataJSON" BLOB NOT NULL,
    "attestationObject" BLOB NOT NULL,
    "originalChallenge" BLOB NOT NULL,
    CONSTRAINT "serverpod_auth_idp_passkey_account_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_idp_passkey_account_key_id_base64" ON "serverpod_auth_idp_passkey_account" ("keyIdBase64");


--
-- Class PasskeyChallenge as table serverpod_auth_idp_passkey_challenge
--
CREATE TABLE "serverpod_auth_idp_passkey_challenge" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "createdAt" INTEGER NOT NULL,
    "challenge" BLOB NOT NULL
) STRICT;


--
-- Class RateLimitedRequestAttempt as table serverpod_auth_idp_rate_limited_request_attempt
--
CREATE TABLE "serverpod_auth_idp_rate_limited_request_attempt" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "domain" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "nonce" TEXT NOT NULL,
    "ipAddress" TEXT,
    "attemptedAt" INTEGER NOT NULL,
    "extraData" TEXT
) STRICT;

-- Indexes
CREATE INDEX "serverpod_auth_idp_rate_limited_request_attempt_composite" ON "serverpod_auth_idp_rate_limited_request_attempt" ("domain", "source", "nonce", "attemptedAt");


--
-- Class SecretChallenge as table serverpod_auth_idp_secret_challenge
--
CREATE TABLE "serverpod_auth_idp_secret_challenge" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "challengeCodeHash" TEXT NOT NULL
) STRICT;


--
-- Class RefreshToken as table serverpod_auth_core_jwt_refresh_token
--
CREATE TABLE "serverpod_auth_core_jwt_refresh_token" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "scopeNames" TEXT NOT NULL,
    "extraClaims" TEXT,
    "method" TEXT NOT NULL,
    "fixedSecret" BLOB NOT NULL,
    "rotatingSecretHash" TEXT NOT NULL,
    "lastUpdatedAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    CONSTRAINT "serverpod_auth_core_jwt_refresh_token_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE INDEX "serverpod_auth_core_jwt_refresh_token_last_updated_at" ON "serverpod_auth_core_jwt_refresh_token" ("lastUpdatedAt");


--
-- Class UserProfile as table serverpod_auth_core_profile
--
CREATE TABLE "serverpod_auth_core_profile" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "userName" TEXT,
    "fullName" TEXT,
    "email" TEXT,
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "imageId" BLOB,
    CONSTRAINT "serverpod_auth_core_profile_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "serverpod_auth_core_profile_fk_1" FOREIGN KEY ("imageId") REFERENCES "serverpod_auth_core_profile_image" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
) STRICT;

-- Indexes
CREATE UNIQUE INDEX "serverpod_auth_profile_user_profile_email_auth_user_id" ON "serverpod_auth_core_profile" ("authUserId");


--
-- Class UserProfileImage as table serverpod_auth_core_profile_image
--
CREATE TABLE "serverpod_auth_core_profile_image" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "userProfileId" BLOB NOT NULL,
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "storageId" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    CONSTRAINT "serverpod_auth_core_profile_image_fk_0" FOREIGN KEY ("userProfileId") REFERENCES "serverpod_auth_core_profile" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;


--
-- Class ServerSideSession as table serverpod_auth_core_session
--
CREATE TABLE "serverpod_auth_core_session" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "authUserId" BLOB NOT NULL,
    "scopeNames" TEXT NOT NULL,
    "createdAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "lastUsedAt" INTEGER NOT NULL DEFAULT (CAST(unixepoch('subsecond') * 1000 AS INTEGER)),
    "expiresAt" INTEGER,
    "expireAfterUnusedFor" INTEGER,
    "sessionKeyHash" BLOB NOT NULL,
    "sessionKeySalt" BLOB NOT NULL,
    "method" TEXT NOT NULL,
    CONSTRAINT "serverpod_auth_core_session_fk_0" FOREIGN KEY ("authUserId") REFERENCES "serverpod_auth_core_user" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
) STRICT;


--
-- Class AuthUser as table serverpod_auth_core_user
--
CREATE TABLE "serverpod_auth_core_user" (
    "id" BLOB PRIMARY KEY DEFAULT (unhex(printf('%012x', CAST(unixepoch('now', 'subsecond') * 1000 AS INTEGER)) || '7' || substr(hex(randomblob(2)), 2, 3) || substr('89AB', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(8)), 2, 15))),
    "createdAt" INTEGER NOT NULL,
    "scopeNames" TEXT NOT NULL,
    "blocked" INTEGER NOT NULL
) STRICT;


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
    ('address', 'id', 'bigint', NULL),
    ('address', 'street', 'text', NULL),
    ('address', 'inhabitantId', 'bigint', NULL),
    ('city', 'id', 'bigint', NULL),
    ('city', 'name', 'text', NULL),
    ('company', 'id', 'bigint', NULL),
    ('company', 'name', 'text', NULL),
    ('company', 'townId', 'bigint', NULL),
    ('organization', 'id', 'bigint', NULL),
    ('organization', 'name', 'text', NULL),
    ('organization', 'cityId', 'bigint', NULL),
    ('person', 'id', 'bigint', NULL),
    ('person', 'name', 'text', NULL),
    ('person', 'organizationId', 'bigint', NULL),
    ('person', 'oldCompanyId', 'bigint', NULL),
    ('person', '_cityCitizensCityId', 'bigint', NULL),
    ('town', 'id', 'bigint', NULL),
    ('town', 'name', 'text', NULL),
    ('town', 'mayorId', 'bigint', NULL),
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
    ('serverpod_auth_idp_anonymous_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_anonymous_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_anonymous_account', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_apple_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_apple_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_apple_account', 'refreshToken', 'text', NULL),
    ('serverpod_auth_idp_apple_account', 'refreshTokenRequestedWithBundleIdentifier', 'boolean', NULL),
    ('serverpod_auth_idp_apple_account', 'lastRefreshedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_apple_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_apple_account', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_apple_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_apple_account', 'isEmailVerified', 'boolean', NULL),
    ('serverpod_auth_idp_apple_account', 'isPrivateEmail', 'boolean', NULL),
    ('serverpod_auth_idp_apple_account', 'firstName', 'text', NULL),
    ('serverpod_auth_idp_apple_account', 'lastName', 'text', NULL),
    ('serverpod_auth_idp_email_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_email_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_email_account', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_email_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_email_account', 'passwordHash', 'text', NULL),
    ('serverpod_auth_idp_email_account_password_reset_request', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_password_reset_request', 'emailAccountId', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_password_reset_request', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_email_account_password_reset_request', 'challengeId', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_password_reset_request', 'setPasswordChallengeId', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_request', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_request', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_email_account_request', 'email', 'text', NULL),
    ('serverpod_auth_idp_email_account_request', 'challengeId', 'uuid', NULL),
    ('serverpod_auth_idp_email_account_request', 'createAccountChallengeId', 'uuid', NULL),
    ('serverpod_auth_idp_facebook_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_facebook_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_facebook_account', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_facebook_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_facebook_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_facebook_account', 'fullName', 'text', NULL),
    ('serverpod_auth_idp_facebook_account', 'firstName', 'text', NULL),
    ('serverpod_auth_idp_facebook_account', 'lastName', 'text', NULL),
    ('serverpod_auth_idp_firebase_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_firebase_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_firebase_account', 'created', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_firebase_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_firebase_account', 'phone', 'text', NULL),
    ('serverpod_auth_idp_firebase_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_github_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_github_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_github_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_github_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_github_account', 'created', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_google_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_google_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_google_account', 'created', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_google_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_google_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_microsoft_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_microsoft_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_microsoft_account', 'userIdentifier', 'text', NULL),
    ('serverpod_auth_idp_microsoft_account', 'email', 'text', NULL),
    ('serverpod_auth_idp_microsoft_account', 'created', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_passkey_account', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_passkey_account', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_idp_passkey_account', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_passkey_account', 'keyId', 'bytea', NULL),
    ('serverpod_auth_idp_passkey_account', 'keyIdBase64', 'text', NULL),
    ('serverpod_auth_idp_passkey_account', 'clientDataJSON', 'bytea', NULL),
    ('serverpod_auth_idp_passkey_account', 'attestationObject', 'bytea', NULL),
    ('serverpod_auth_idp_passkey_account', 'originalChallenge', 'bytea', NULL),
    ('serverpod_auth_idp_passkey_challenge', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_passkey_challenge', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_passkey_challenge', 'challenge', 'bytea', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'domain', 'text', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'source', 'text', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'nonce', 'text', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'ipAddress', 'text', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'attemptedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_idp_rate_limited_request_attempt', 'extraData', 'json', NULL),
    ('serverpod_auth_idp_secret_challenge', 'id', 'uuid', NULL),
    ('serverpod_auth_idp_secret_challenge', 'challengeCodeHash', 'text', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'id', 'uuid', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'extraClaims', 'text', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'method', 'text', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'fixedSecret', 'bytea', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'rotatingSecretHash', 'text', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'lastUpdatedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_jwt_refresh_token', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_profile', 'id', 'uuid', NULL),
    ('serverpod_auth_core_profile', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_profile', 'userName', 'text', NULL),
    ('serverpod_auth_core_profile', 'fullName', 'text', NULL),
    ('serverpod_auth_core_profile', 'email', 'text', NULL),
    ('serverpod_auth_core_profile', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_profile', 'imageId', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'id', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'userProfileId', 'uuid', NULL),
    ('serverpod_auth_core_profile_image', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_profile_image', 'storageId', 'text', NULL),
    ('serverpod_auth_core_profile_image', 'path', 'text', NULL),
    ('serverpod_auth_core_profile_image', 'url', 'text', NULL),
    ('serverpod_auth_core_session', 'id', 'uuid', NULL),
    ('serverpod_auth_core_session', 'authUserId', 'uuid', NULL),
    ('serverpod_auth_core_session', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_session', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'lastUsedAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'expiresAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_session', 'expireAfterUnusedFor', 'bigint', NULL),
    ('serverpod_auth_core_session', 'sessionKeyHash', 'bytea', NULL),
    ('serverpod_auth_core_session', 'sessionKeySalt', 'bytea', NULL),
    ('serverpod_auth_core_session', 'method', 'text', NULL),
    ('serverpod_auth_core_user', 'id', 'uuid', NULL),
    ('serverpod_auth_core_user', 'createdAt', 'timestampWithoutTimeZone', NULL),
    ('serverpod_auth_core_user', 'scopeNames', 'json', NULL),
    ('serverpod_auth_core_user', 'blocked', 'boolean', NULL);

--
-- MIGRATION VERSION FOR serverpod_offline_sync_test
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync_test', '20260415021710222', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260415021710222', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260324085808546', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085808546', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260324085850822', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085850822', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260406022300405', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260406022300405', "timestamp" = (unixepoch('now', 'subsecond') * 1000);

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260324085844499', (unixepoch('now', 'subsecond') * 1000))
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085844499', "timestamp" = (unixepoch('now', 'subsecond') * 1000);


COMMIT;
