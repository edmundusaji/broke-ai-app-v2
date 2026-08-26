# PRD: Offline-First Guest and Account Mode

**Status:** Draft for product and engineering review  
**Date:** 2026-08-25  
**Product:** Broke.AI  
**Platforms:** Android, iOS, and other Flutter-supported client platforms where local storage is available

> [!IMPORTANT]
> **Branch restriction:** All frontend, backend, database migration, test, and documentation work defined by this PRD must be created and reviewed only on the `develop` branch. Frontend pull requests must target `develop` in `broke-ai-app-v2`; backend and database pull requests must target `develop` in `broke-ai`. Promotion to `master` or production is outside this PRD.

## 1. Summary

Broke.AI will become an offline-first expense tracker for both guests and registered users. After the app has been installed, users must be able to open it, view locally available financial data, create manual transactions, edit transactions, and delete transactions without network connectivity.

The Flutter app will use an on-device transactional database as the source of truth for user-facing transaction data. Network requests will synchronize that database with the Broke.AI backend when connectivity is available. A durable outbox will preserve local changes across app restarts and safely retry them without creating duplicates.

Registered users will retain cloud backup and multi-device synchronization. Guests will receive a stable device-local identity that works without contacting the server. When a guest later connects or registers, their local data will be uploaded and associated with the resulting server account without requiring re-entry.

AI processing remains server-dependent for this release. Users may capture a receipt image or enter notification text while offline, but analysis occurs after connectivity returns unless a separate on-device AI feature is approved later.

This feature requires coordinated frontend, backend, and database changes. A frontend-only queue is insufficient because it cannot reliably prevent duplicate creates, resolve concurrent edits, propagate deletions, or merge offline guest data.

## 2. Current state

### 2.1 Flutter application

The current Flutter app:

- stores guest and registered sessions in secure storage;
- allows a stored session to be used without an immediate network validation while its JWT remains unexpired;
- treats an expired JWT as no session, even when cached user data could still be used offline;
- stores account, notification, privacy, appearance, currency, and language preferences locally with a limited pending-sync mechanism;
- loads dashboard summary, monthly history, and recent transactions directly from the backend;
- sends manual create, edit, and delete operations directly to the backend;
- shows an error state when dashboard or history requests fail;
- has no local relational or transactional database for expenses;
- writes failed receipt and pasted-notification submissions to a SharedPreferences string list named `offline_queue`; and
- does not contain a worker that replays, scopes, deduplicates, expires, or displays that queue.

The current queued receipt payload stores the path returned by the image picker. That file may be temporary and can disappear before the app reconnects. The current broad error handling can also queue validation and authorization failures that should not be retried.

### 2.2 Backend API

The current REST API provides:

- guest login, account login, registration, guest upgrade, and guest merge;
- monthly history, summary, and recent transaction reads;
- manual transaction create, update, and delete;
- receipt and notification AI processing;
- profile, settings, privacy, device, and account-security APIs; and
- `GET /api/v1/me/sync-status`.

It does not provide a transaction change feed, batch mutation endpoint, cursor-based pull, client mutation idempotency contract, or explicit stale-update conflict response. `sync-status` reports account state but does not synchronize records.

Authentication currently returns one expiring JWT and no refresh-token contract. Server-side session records exist, but the token stored there is the ordinary JWT rather than a separately rotated refresh token.

### 2.3 PostgreSQL schema

The current transaction table already has useful synchronization foundations:

- server-generated numeric transaction ID;
- `created_at` and `updated_at` timestamps;
- per-record `revision` managed through JPA optimistic versioning;
- `deleted_at` soft-deletion timestamp; and
- user ownership.

The database also has `idempotency_records` and `user_sync_state`, including an account-level `server_revision`. However:

- transactions do not have a stable client-generated ID;
- history queries exclude deleted records, so deletion tombstones cannot reach other devices;
- account `server_revision` is not tied to an ordered change feed;
- ordinary transaction creates do not use the idempotency table;
- updates do not require the client's base revision; and
- no durable record identifies which entity changed at each account revision.

## 3. Problem statement

Expense entry often happens in unreliable network conditions. A user may be traveling, underground, out of data, or using a temporarily unavailable backend. Requiring a successful request before showing or saving an expense creates four product failures:

1. users cannot access their recent financial history when the server is unreachable;
2. manual expenses are lost or must be re-entered;
3. guest mode is unavailable on a fresh installation without internet; and
4. naive retry can create duplicates or overwrite changes from another device.

Financial records require stronger guarantees than an unstructured retry list. Local operations must survive process termination, retain account ownership, be visible immediately, replay idempotently, and surface conflicts rather than silently losing data.

## 4. Product principles and definitions

### 4.1 Offline-first

For transaction features, the app reads from and writes to the local database first. A successful local database commit is a successful product action. Cloud synchronization is a separate background state and must not block the user interface.

### 4.2 Offline-capable

A feature is offline-capable when its core user outcome completes without a server response. Manual transaction CRUD and viewing cached history are offline-capable. Capturing a receipt for later analysis is offline-capable; AI extraction itself is not.

### 4.3 Online-only

A feature is online-only when the server must verify identity, security state, uniqueness, or external processing. Login, registration, password changes, session revocation, account deletion, username availability, remote data export, and AI analysis are online-only in this release.

### 4.4 Synchronization

Synchronization means pushing durable local mutations and pulling ordered server changes until the local account cursor matches the server. Connectivity detection alone does not imply that synchronization succeeded.

### 4.5 Account scope

Every local record must belong to an immutable account scope. A username, email, bearer token, or display name must not be used as the scope because each can change or expire.

## 5. Goals and success metrics

### Goals

- Let guests enter and use manual expense tracking on a fresh installation with no internet.
- Let previously authenticated users continue using cached financial data after their JWT expires, while keeping server actions locked until reauthentication or token refresh.
- Make dashboard, history, summary, recent activity, and manual transaction CRUD work from local data.
- Preserve local changes across process death, device reboot, network transitions, and temporary backend failure.
- Synchronize without duplicate transactions under repeated, concurrent, or ambiguous retries.
- Propagate edits and deletions across devices.
- Detect stale updates and preserve both local intent and current server data until resolved.
- Migrate guest data into a new or existing registered account safely.
- Prevent any local data from being displayed or synchronized under the wrong account.
- Keep existing settings fallback, receipt scanning, pasted notification processing, automatic notification capture, export, and app-lock flows compatible.

### Initial success metrics

- 100% of locally confirmed manual creates, edits, and deletes survive app restart and airplane-mode testing.
- Zero duplicate server transactions for the same client transaction ID or mutation operation ID across retry and concurrency tests.
- At least 95% of retryable pending mutations reach a terminal state within 60 seconds after stable connectivity and valid authentication return.
- Cached dashboard and current-month history render in under 500 ms at the 95th percentile on supported test devices with 10,000 local transactions.
- Zero cross-account data exposure in automated account-switch, logout, guest-upgrade, and session-expiration tests.
- 100% of simulated stale-update cases return a deterministic conflict outcome; none silently overwrite the other version.
- No queued receipt image or notification text is lost before its documented retention limit unless the user explicitly deletes it, logs out without migration, or deletes the associated account.

## 6. Non-goals

- Running Gemini or equivalent cloud AI without connectivity.
- Adding an on-device OCR or large language model.
- Allowing first-time account login, registration, password reset, or email verification offline.
- Guaranteeing background synchronization when the operating system has force-stopped the app.
- Real-time collaborative editing.
- Synchronizing app-lock PINs or biometric material to the backend.
- Replacing PostgreSQL with a client-replicated database product.
- Making support tickets, security session management, account deletion, or server-generated data exports offline-capable.
- Automatically resolving financial-data conflicts by silently choosing the latest device timestamp.

## 7. User modes and expected behavior

### 7.1 New offline guest

1. The user installs and opens Broke.AI without connectivity.
2. The user selects **Try Now**.
3. The app creates a stable local guest account scope and opens the dashboard immediately.
4. The user may create, edit, delete, search, filter, and export local manual transactions.
5. The app clearly indicates that cloud backup and AI processing require connectivity.
6. When online, the app bootstraps a server guest identity idempotently and uploads the guest's local mutations.

### 7.2 Returning guest

- The same device-local guest scope is restored after app restart.
- Manual transactions remain available regardless of server token state.
- Server-backed guest AI trials remain authoritative. Queued AI requests are processed in FIFO order only while trials remain.
- Exhausted or rejected queued AI items remain available for manual completion or account upgrade; they are not silently discarded.

### 7.3 Returning registered user

- Cached account data remains available without connectivity.
- App lock, if enabled, still protects entry.
- Local manual CRUD remains available and is marked pending.
- When authentication is still valid, synchronization resumes automatically.
- When authentication cannot be refreshed, the app keeps local data visible but displays **Sign in to sync**. It must not clear the account's local data merely because a token expired.

### 7.4 Account switching and logout

- Switching accounts changes the active local scope atomically.
- One account's cached data must never appear while another account is active.
- Normal logout removes authentication secrets and pauses that scope's synchronization.
- Product must offer a clear choice between keeping encrypted local data for later sign-in and removing local data from this device.
- Account deletion removes or cryptographically erases the associated local data after the server confirms the deletion request. If offline, the app must not claim that remote deletion completed.

### 7.5 Guest registration or merge

- **Create account:** locally queued guest data becomes owned by the upgraded account without creating a second visible copy.
- **Sign in to existing account:** guest mutations are pushed/merged idempotently, then the resulting registered-account change feed is pulled.
- The transition must be resumable after interruption. A process crash between upload and scope migration must not duplicate or orphan data.

## 8. Feature availability matrix

| Feature | Offline guest | Offline registered user | Reconnect behavior |
|---|---:|---:|---|
| Open app and pass app lock | Yes | Yes | No action required |
| View cached dashboard/history | Yes | Yes | Pull latest changes |
| Calculate summary/recent totals | Yes, locally | Yes, locally | Reconcile local records |
| Create manual transaction | Yes | Yes | Push idempotently |
| Edit/delete local transaction | Yes | Yes | Push with base revision |
| Edit/delete previously synced transaction | Yes | Yes | Detect remote conflicts |
| Capture receipt image | Yes, queue | Yes, queue | Upload and run AI |
| Process receipt with AI | No | No | Process FIFO when eligible |
| Enter notification text | Yes, queue or save manually | Yes, queue or save manually | Run AI if requested |
| Automatic Android notification capture | Queue per its dedicated PRD | Queue per its dedicated PRD | Existing durable worker uploads |
| Theme/currency/language/privacy settings | Yes | Yes | Sync account-backed settings |
| Local data export | Yes | Yes | No action required |
| Complete server data export | No | No | User retries online |
| Login/register/guest merge | No | No | User completes online |
| Profile/security/account deletion | Cached view only | Cached view only | Mutations require server verification |
| Support ticket submission | Draft locally, optional | Draft locally, optional | Submit after confirmation |

## 9. Product requirements

### 9.1 Local source of truth

- Dashboard, history, summary, recent activity, and transaction detail must render from the local database.
- A network response must update the local database and then let reactive local queries update the UI. Network DTOs must not be the direct long-lived state of these screens.
- Summary and category breakdown must be calculated from active local transactions using the selected account scope, currency rules, and month.
- Pull-to-refresh starts synchronization but continues showing current local data. It must not replace populated content with a full-screen error.
- Empty state and unavailable state must be distinct. An account with no local transactions is empty; a failed first synchronization is not proof that the server account is empty.

### 9.2 Manual transaction behavior

- Create, edit, and delete commit locally in one database transaction with the corresponding outbox operation.
- The updated UI appears immediately.
- Pending records display a subtle synchronization status without blocking normal use.
- A user can retry a failed mutation, inspect a safe error message, or discard the local mutation.
- Deletion creates a local tombstone. The row disappears from ordinary history but remains in local synchronization storage until server acknowledgement and retention cleanup.
- Undo may be offered before synchronization. After server acknowledgement, restoration must be represented as a new explicit mutation rather than silently removing a tombstone.

### 9.3 Synchronization status UI

The app must expose account-level status in a compact, accessible form:

- **Up to date**;
- **Offline — changes saved on this device**;
- **Syncing**;
- **N changes waiting**;
- **Sign in to sync**;
- **Some changes need attention**; or
- **Sync failed — retry**.

Transaction-level status is required for `pending`, `failed`, and `conflict`. Fully synchronized items do not need a persistent badge.

The UI must not state that data is backed up merely because it was saved locally.

### 9.4 Retry classification

- Retry automatically: connection failure, timeout, HTTP 408, HTTP 425, HTTP 429, and retryable HTTP 5xx.
- Pause for authentication: expired/revoked token or refresh failure.
- Mark conflict: stale base revision or an incompatible remote tombstone.
- Mark terminal failure: invalid payload, unsupported mutation, ownership rejection, or a business rule that cannot succeed unchanged.
- Honor `Retry-After` when provided.
- Use exponential backoff with jitter and a bounded maximum interval.
- Connectivity plugins may improve scheduling but must not be treated as proof that the backend is reachable.

### 9.5 Conflict behavior

The MVP must use optimistic concurrency rather than last-device-write-wins:

- Create is identified by immutable `clientTransactionId`; repeated creates return the existing server transaction.
- Update includes `baseRevision`. It succeeds only when that revision matches the active server record.
- Delete includes `baseRevision` and follows the same rule.
- A stale update or delete returns the current server version and a structured conflict code.
- The client preserves its local draft and the server version.
- The user may choose **Keep mine**, **Use server version**, or, for an update against a remote deletion, **Save mine as a new transaction**.
- Conflict resolution produces a new idempotent operation with the newest server revision.
- Device clocks must not decide conflict winners.

### 9.6 Receipt and notification AI queue

- Offline receipt capture must copy the selected image into app-private persistent storage before confirming that it was saved.
- Queue metadata and file references must be stored transactionally, not in a SharedPreferences string list.
- Sensitive queued content must be encrypted at rest using platform-backed key storage where available.
- Queue entries are account-scoped and include an immutable operation ID, creation time, retention deadline, attempt count, next attempt time, and safe last-error code.
- Only network/retryable server failures enter automatic retry. Validation, authorization, and trial-limit responses follow their explicit terminal states.
- AI results are written into the same local transaction table and synchronized like any other server-created transaction.
- Guest AI trial count remains server-authoritative. Offline capture does not guarantee processing and does not grant additional trials.
- Queued AI work must not block manual entry. A failed extraction can be converted into a manual transaction using retained user-provided content.

### 9.7 Settings, profile, and security

- Existing local-first preference behavior must migrate from mutable username scoping to immutable account scoping.
- Appearance and locale preferences apply immediately and synchronize later where supported.
- Cached profile identity may be displayed offline with an **Offline copy** indication.
- Username, email, avatar, password, session, notification-capture credential, and account-deletion mutations remain online-only unless separately specified.
- App-lock secrets remain strictly local and never enter the sync database or backend payload.

## 10. Technical design

### 10.1 End-to-end architecture

```text
Flutter screens and providers
          ↓ reactive queries
Encrypted/account-scoped local database
    ├── transactions and tombstones
    ├── pending AI captures/attachments
    ├── durable mutation outbox
    └── per-account sync cursor
          ↕
Foreground/background sync coordinator
          ↕ push operations / pull changes
Versioned backend synchronization API
          ↕
PostgreSQL transactions + ordered change log
```

### 10.2 Frontend changes (`broke-ai-app-v2`, `develop` only)

#### Local persistence

Use SQLite through Drift or an equivalently typed, migration-capable Flutter database. The selected library must support transactions, indexes, background-isolate access where needed, deterministic migrations, and Android/iOS production use.

Minimum local tables:

**`local_accounts`**

- `scope_id` immutable local primary key;
- `server_account_id` nullable stable server identifier;
- `kind` (`guest` or `registered`);
- cached display identity;
- authentication/sync state;
- created and last-active timestamps.

**`transactions`**

- `client_transaction_id` UUID primary identity across client/server;
- nullable legacy `server_id`;
- `account_scope_id`;
- expense fields and source metadata;
- `server_revision` nullable;
- `created_at`, `local_updated_at`, and nullable `server_updated_at`;
- nullable `deleted_at`;
- `sync_state` (`local`, `pending`, `synced`, `failed`, `conflict`);
- safe terminal error code; and
- optional conflict snapshot reference.

**`mutation_outbox`**

- `operation_id` UUID;
- account and entity IDs;
- operation type (`CREATE`, `UPDATE`, `DELETE`);
- canonical payload or payload reference;
- nullable `base_revision`;
- attempt and scheduling fields;
- authentication requirement; and
- terminal state/error code.

**`sync_cursors`**

- account scope;
- opaque server cursor;
- last successful push/pull timestamps; and
- last observed server revision.

**`pending_captures` and `local_attachments`**

- immutable queue/attachment IDs;
- account ownership;
- private copied file path or encrypted payload reference;
- type, retention deadline, state, and retry metadata.

Foreign keys and account-scope indexes are required. Every query returning user data must include the active scope through the repository layer, not ad hoc widget filtering.

#### Repository and state management

- Introduce a transaction repository that exposes local reactive queries and local mutation methods.
- Replace direct `ApiClient` calls from widgets with repository/use-case methods.
- Refactor `dashboardProvider` to observe local data and separate `syncStatusProvider` from content state.
- Recalculate summaries locally after every committed mutation or pulled change.
- Keep API DTOs, local entities, and presentation models separate enough to support migrations and conflict snapshots.
- Replace `refreshTransactionState` invalidation with repository-driven reactive updates; refresh should request synchronization.

#### Sync coordinator

- Serialize synchronization per account scope.
- Coalesce compatible pending updates to the same unsynchronized transaction while preserving the original operation ID rules.
- Push a bounded batch, apply per-operation results transactionally, then pull until the server indicates no additional pages.
- Never advance the local cursor unless the corresponding change page was fully committed.
- Prevent two workers in the same process from pushing the same outbox row concurrently.
- Resume safely after termination at every network/database boundary.
- Run after login/guest bootstrap, app foreground, explicit refresh, local mutation, and credible connectivity restoration.
- Use OS background scheduling where practical, but foreground correctness is mandatory even when background work is delayed.

#### Session model

Split local access from server authentication:

- `localAccountAvailable`: cached account data may be opened;
- `accessTokenValid`: authenticated API requests may run;
- `refreshAvailable`: the client may attempt silent token rotation; and
- `reauthenticationRequired`: local data remains available but sync is paused.

Token expiration must not delete transactions, clear account scope, or force the user into an empty onboarding state. Explicit logout/account removal remains distinct from expiration.

### 10.3 Backend changes (`broke-ai`, `develop` only)

#### Stable identity and authentication

- Return an immutable `accountId` in login, guest bootstrap, guest upgrade/merge, and current-user responses.
- Add a refresh-token rotation contract for registered accounts and server-backed guests, or explicitly require reauthentication after access-token expiration while preserving local-only access.
- Store only hashed refresh tokens, rotate them on use, support revocation, and keep device/session management compatible.
- Make guest bootstrap idempotent for an installation-provided `clientGuestId`. A retry must return the same active guest identity when authorized by the installation credential rather than creating unlimited abandoned guests.

#### Proposed synchronization endpoints

`POST /api/v1/sync/push`

- bearer authentication;
- accepts a bounded ordered array of mutations;
- treats `operationId` as an idempotency key scoped to user and operation;
- validates that `clientTransactionId` belongs to the authenticated account;
- applies each accepted operation transactionally with its change-log entry;
- returns one result per operation; and
- supports partial batch success without making already accepted operations unsafe to retry.

Example request:

```json
{
  "deviceId": "59a30545-4681-4e8d-8a65-e8dbb872abdb",
  "operations": [
    {
      "operationId": "ee383f63-a4bc-4279-bf74-5bc7d6389b2d",
      "type": "CREATE",
      "clientTransactionId": "c3313484-cbbc-44f1-b535-e67f1d60d4d4",
      "baseRevision": null,
      "transaction": {
        "date": "2026-08-25",
        "amount": 75000,
        "category": "Food",
        "paymentMethod": "GoPay",
        "description": "Dinner"
      }
    }
  ]
}
```

Example result:

```json
{
  "results": [
    {
      "operationId": "ee383f63-a4bc-4279-bf74-5bc7d6389b2d",
      "status": "APPLIED",
      "transaction": {
        "id": 481,
        "clientTransactionId": "c3313484-cbbc-44f1-b535-e67f1d60d4d4",
        "revision": 1,
        "updatedAt": "2026-08-25T09:12:00Z"
      }
    }
  ],
  "serverRevision": 1084
}
```

Required operation statuses are `APPLIED`, `DUPLICATE`, `CONFLICT`, `REJECTED`, and `RETRYABLE_FAILURE`.

`GET /api/v1/sync/pull?cursor={opaqueCursor}&limit={n}`

- returns ordered transaction upserts and deletion tombstones after the supplied cursor;
- scopes every result to the authenticated user;
- uses an opaque cursor rather than a client timestamp;
- returns `nextCursor` and `hasMore`;
- provides current record revision and server timestamp; and
- retains tombstones/change entries long enough to support the documented offline window.

Example response:

```json
{
  "changes": [
    {
      "sequence": 1084,
      "type": "TRANSACTION_UPSERT",
      "clientTransactionId": "c3313484-cbbc-44f1-b535-e67f1d60d4d4",
      "revision": 2,
      "transaction": {}
    },
    {
      "sequence": 1085,
      "type": "TRANSACTION_DELETE",
      "clientTransactionId": "f60a787a-25b0-45f3-9cd1-bd55d6584904",
      "revision": 4,
      "deletedAt": "2026-08-25T09:15:00Z"
    }
  ],
  "nextCursor": "opaque:1085",
  "hasMore": false,
  "serverRevision": 1085
}
```

The existing history/recent/summary endpoints remain compatible during migration and may continue serving older clients.

#### Backend mutation rules

- Validate monetary values, ownership, allowed fields, and record state on every push.
- Reserve or look up idempotency before applying a mutation.
- Persist the entity change and corresponding change-log row in the same database transaction.
- Return the original terminal response for a repeated `operationId` with the same request hash.
- Return `409 IDEMPOTENCY_KEY_REUSED` when an operation ID is reused for a different payload.
- Return `409 TRANSACTION_REVISION_CONFLICT` with the current safe server representation when `baseRevision` is stale.
- Do not expose another user's record through a conflict or ownership error.
- Apply documented batch, payload-size, and rate limits.

### 10.4 Database changes (`broke-ai`, Flyway migration on `develop` only)

Create new sequential Flyway migrations; do not modify migrations already applied to any environment.

#### Extend `receipt`

- Add `client_transaction_id UUID`.
- Backfill every existing active and deleted row with a generated UUID.
- Make it non-null after backfill.
- Add a unique constraint or index on `(user_id, client_transaction_id)`.
- Retain the existing numeric ID for compatibility.
- Retain and use `revision`, `created_at`, `updated_at`, and `deleted_at`.

#### Add ordered change log

Create a table such as `user_change_log` with:

- monotonic `sequence BIGINT` primary key;
- `user_id`;
- entity type;
- `client_entity_id`;
- change type (`UPSERT` or `DELETE`);
- resulting entity revision;
- server creation timestamp; and
- optional safe snapshot or sufficient reference to reconstruct the version required by pull.

Add an index on `(user_id, sequence)`. Change-log retention must exceed the maximum supported offline duration. If a cursor predates retained history, pull returns `CURSOR_EXPIRED`, and the client performs a paginated full reconciliation that includes current tombstone policy.

#### Idempotency

Reuse `idempotency_records` for synchronization operations with:

- operation name `TRANSACTION_CREATE`, `TRANSACTION_UPDATE`, or `TRANSACTION_DELETE`;
- client `operationId` as the idempotency key;
- canonical request hash;
- terminal status/body; and
- retention long enough to cover supported offline retry periods.

If the existing response-body design cannot safely retain batch results, introduce a dedicated mutation receipt table rather than weakening idempotency.

#### Guest bootstrap mapping

Store an installation-scoped guest bootstrap identifier or its safe hash with a uniqueness constraint that makes guest creation retry-safe. It must not become a public authentication secret by itself.

#### Refresh sessions

If refresh-token rotation is selected, separate access-token and refresh-token semantics. Store hashed refresh tokens, family/rotation state, expiration, revocation, device ownership, and reuse-detection metadata. Do not continue naming an access-token hash as a refresh token.

## 11. Data migration and compatibility

### 11.1 First upgraded app launch

- Create the local schema before rendering transaction screens.
- Restore the local account record from the stored session and cached identity.
- For each account, perform a one-time authenticated full import of server history when available.
- Write imported records using server-provided `clientTransactionId`. For legacy rows, the backend migration supplies one.
- Mark the initial cursor only after all imported pages commit.
- If offline, allow the user to enter the app with whatever local data exists and defer import.

### 11.2 Existing `offline_queue`

- Parse valid legacy entries once.
- Copy existing receipt files into private persistent storage when the referenced file still exists.
- Migrate notification text into the new account-scoped pending-capture table.
- Mark missing files as user-action-required rather than retrying forever.
- Do not infer that every queued item is retryable; revalidate its type and authentication scope.
- Remove the legacy SharedPreferences key only after successful migration or explicit per-item terminal recording.

### 11.3 Older clients

- Existing transaction endpoints remain operational throughout rollout.
- Server-created and older-client-created transactions receive a `client_transaction_id` automatically.
- Every legacy mutation must still emit a change-log entry so offline-first clients receive it.
- The sync API must be versioned or backward-compatible before the first local-first frontend build is distributed.

## 12. Security and privacy requirements

- Local financial records must use platform-appropriate encrypted storage or database encryption with keys protected by Android Keystore, iOS Keychain/Secure Enclave capabilities, or the closest supported equivalent.
- Authentication tokens remain in secure storage and must not be copied into ordinary database rows or logs.
- Every local and backend query must enforce account ownership.
- Logout, account switch, and guest merge must be tested for data-boundary failures.
- Receipt images and raw notification text must be stored in private app storage, encrypted where required, excluded from cloud device backups unless explicitly approved, and deleted after terminal processing plus the documented recovery period.
- Sync payloads require TLS. Offline synchronization must not ship while the production base URL uses cleartext HTTP.
- Logs, analytics, and crash reports must not contain transaction descriptions, amounts, receipt images, raw notification content, bearer/refresh tokens, operation payloads, or database encryption keys.
- Background workers must stop or pause when account ownership/authentication changes.
- App-lock secrets remain outside synchronized storage.
- Local data deletion must distinguish device-only removal from server account/data deletion and use precise user-facing language.

## 13. Analytics and observability

Allowed operational events include:

- sync started/completed/paused;
- counts of applied, duplicate, conflict, rejected, and retryable operations;
- queue-depth bucket;
- change-page count and latency bucket;
- cursor-expired/full-reconciliation event;
- database migration success/failure; and
- guest bootstrap or merge outcome.

Metrics must not contain financial fields, free-form descriptions, receipt content, notification content, tokens, raw UUIDs that unnecessarily identify a user, or request/response bodies.

The backend should expose internal health metrics for change-log lag, idempotency reuse conflicts, mutation error rates, pull latency, and guest-bootstrap failures. Alerts must distinguish authentication pauses from infrastructure failures.

## 14. Testing plan

### 14.1 Flutter automated tests

- Local schema creation and every migration path.
- Account-scope isolation and account switching.
- Guest creation without any API implementation available.
- Manual create/edit/delete while offline, including process restart.
- Reactive dashboard/history/summary updates after local mutations.
- Outbox creation in the same transaction as entity changes.
- Retry classification and exponential-backoff state.
- Token expiration preserving local account access.
- Push result handling for applied, duplicate, conflict, rejected, and retryable outcomes.
- Pull upsert/tombstone application and cursor atomicity.
- Crash simulation before request, after server commit/before response, and after response/before local acknowledgement.
- Conflict preservation and resolution actions.
- Legacy `offline_queue` migration.
- Receipt-file persistence, expiration, missing file, logout, and account removal.
- Guest upgrade/merge interruption and recovery.
- Widget states for offline, pending, syncing, failed, reauthentication-required, and conflict.
- Regression coverage for settings, app lock, export, AI trial messaging, and automatic notification capture.

Run at minimum:

```bash
flutter analyze
flutter test
```

### 14.2 Backend automated tests

- Guest bootstrap idempotency and authorization.
- Refresh rotation, expiration, revocation, and reuse detection if implemented.
- Push authentication, ownership, validation, batch limits, and rate limits.
- Repeated and concurrent create with the same transaction and operation IDs.
- Idempotency-key reuse with different payloads.
- Matching and stale update/delete revisions.
- Change-log atomicity with create/update/delete and legacy endpoints.
- Ordered paginated pull with stable cursor behavior.
- Tombstone delivery and cursor expiration.
- Full reconciliation for a cursor older than retention.
- Guest-to-account upgrade and existing-account merge with retries.
- Cross-user record and cursor attacks.
- PostgreSQL migration on clean schema and upgrade with existing active/deleted receipt rows.
- Performance tests for large histories and outbox batches.

Run at minimum:

```bash
./mvnw test
```

### 14.3 Integration and chaos matrix

Verify on physical Android and iOS devices where supported:

- first launch offline and online;
- returning guest and registered accounts;
- valid token, expired token, revoked token, and refresh failure;
- airplane mode during create, edit, delete, receipt capture, push, and pull;
- server commits then drops the connection before responding;
- app terminated before and after each sync boundary;
- device reboot with pending work;
- two devices editing the same transaction;
- one device deleting while another edits;
- guest registration/merge interrupted at each step;
- account logout/login to the same account and a different account;
- 10,000 local transactions and large pending queues;
- backend 400, 401, 403, 409, 429, and 5xx responses;
- cursor expiration and full reconciliation;
- local database migration failure and safe recovery; and
- low storage, missing attachment, and corrupted queued payload behavior.

## 15. Acceptance criteria

The feature is ready for internal release on `develop` when:

- a new user can enter guest mode and save manual expenses with the device fully offline;
- a previously authenticated user can open cached data and perform manual CRUD after the access token expires;
- dashboard, monthly history, recent activity, and summary render exclusively from the active account's local data;
- every local mutation creates a durable outbox operation atomically;
- ambiguous request retries create no duplicate server transaction;
- server edits and deletions reach another device through the ordered pull feed;
- stale edits never silently overwrite current server data;
- pending, failed, authentication-paused, and conflict states are visible and actionable;
- guest upgrade and merge preserve all eligible local transactions without duplicates;
- queued receipt images survive process restart and reconnect or show a precise terminal state;
- legacy queued items are migrated or safely surfaced;
- no account can display or sync another account's local data;
- cleartext HTTP is removed from the release configuration;
- clean-install and upgrade database migrations pass;
- frontend, backend, migration, and integration test suites pass; and
- all implementation remains on `develop` pending a separate promotion decision.

## 16. Rollout plan

1. Finalize immutable account identity, sync protocol, conflict policy, retention, and encryption decisions.
2. Add backward-compatible backend IDs, change log, idempotent push/pull endpoints, and migrations behind a disabled feature flag.
3. Add the local database in shadow-read mode and compare local calculations against existing API responses in development.
4. Migrate dashboard/history reads to local data while server mutations remain authoritative.
5. Enable local-first manual CRUD and outbox synchronization for internal guest accounts.
6. Enable registered-account synchronization and multi-device conflict handling for internal testers.
7. Enable durable AI capture migration and reconnect processing.
8. Run chaos, migration, security, performance, and account-isolation testing.
9. Roll out to a small internal cohort with queue/conflict/lag monitoring.
10. Product owner separately decides whether the completed `develop` work may be promoted.

Every rollout phase must be remotely disableable without deleting local data. Disabling server synchronization must leave the app in a truthful local-only state and preserve pending operations for later retry.

## 17. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Duplicate expenses after an ambiguous timeout | Immutable client transaction ID plus operation idempotency and stored terminal responses |
| Local changes overwrite another device | Required base revision, structured conflicts, explicit user resolution |
| Remote deletions reappear | Durable tombstones and ordered change feed |
| Data leaks during account switching | Immutable account scopes, repository-enforced ownership, isolation tests |
| Token expires during a long offline period | Separate local access from authentication; refresh or explicit sign-in-to-sync state |
| Guest retry creates multiple server guests | Idempotent installation-scoped guest bootstrap |
| Receipt image path disappears | Copy into private persistent storage before confirming queue success |
| Queue grows indefinitely | Retention, caps, retry states, user-visible management, and terminal classification |
| Device and server clocks disagree | Opaque server cursor and revision rules; clocks never choose conflict winners |
| Change log grows too large | Documented retention, indexed cursor queries, cursor-expired full reconciliation |
| Local database migration fails | Versioned migrations, backups/recovery strategy, no destructive fallback without consent |
| Sensitive data appears in logs or backups | Encrypted storage, log redaction, backup policy, automated privacy assertions |
| Existing clients miss new changes | Legacy endpoints emit change-log entries and receive generated client IDs |
| Cleartext transport exposes financial data | HTTPS is a release gate |

## 18. Dependencies and open decisions

Product and engineering must confirm before implementation:

- Drift/SQLite versus another supported local database and encryption approach;
- whether encrypted local data remains after normal logout by default;
- maximum supported offline duration and change-log/idempotency retention;
- refresh-token implementation versus explicit reauthentication for sync;
- immutable server `accountId` format;
- guest bootstrap credential and abuse controls;
- maximum push batch size and pull page size;
- whether conflicts receive a dedicated inbox or transaction-level resolution only;
- whether local export includes pending and conflicted transactions and how they are labeled;
- AI capture retention duration and guest behavior when queued items exceed remaining trials;
- background execution expectations by platform;
- full-reconciliation behavior when a cursor expires;
- database encryption/key recovery behavior after device credential changes; and
- final offline, backup, deletion, and reauthentication copy.

## 19. Related work and references

- `PRD_AUTOMATIC_NOTIFICATION_EXPENSE_CAPTURE.md` for the Android automatic-capture queue and scoped device credential.
- [Flutter offline-first architecture guidance](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [Android app data and files](https://developer.android.com/training/data-storage)
- [Android WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent)
- [Apple BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks)
- [HTTP idempotent methods](https://www.rfc-editor.org/rfc/rfc9110.html#name-idempotent-methods)

