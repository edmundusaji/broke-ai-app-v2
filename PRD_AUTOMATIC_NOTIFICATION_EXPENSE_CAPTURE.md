# PRD: Automatic Expense Capture from Android Notifications

**Status:** Draft for engineering review  
**Date:** 2026-08-24  
**Product:** Broke.AI  
**Platforms:** Android first; existing manual notification input remains available on all supported platforms

> [!IMPORTANT]
> **Branch restriction:** All frontend, backend, database migration, test, and documentation work defined by this PRD must be created and reviewed only on the `develop` branch. Frontend pull requests must target `develop` in `broke-ai-app-v2`; backend and database pull requests must target `develop` in `broke-ai`. Do not commit, merge, deploy, or backport this feature to `master` as part of this delivery scope.

## 1. Summary

Broke.AI will offer an optional Android feature that reads payment notifications from user-selected supported financial apps, extracts expense details, and adds valid expenses to the user's transaction history without requiring the user to paste the notification manually.

The user must explicitly enable the feature, accept a prominent privacy disclosure, and grant Android Notification Access. The app must continue to work normally if the user declines or later revokes access.

The feature is Android-only for this release. iOS and other platforms continue to support receipt scanning and manual text entry but must not display a nonfunctional automatic-capture toggle.

## 2. Current state

The current Flutter v2 app:

- lets the user paste or type notification text on the Scan page;
- sends `{ "text": "..." }` to `POST /api/v1/expense/notification`;
- refreshes the dashboard after a successful response;
- does not contain an Android `NotificationListenerService` or request Notification Access;
- has an `offline_queue`, but no implemented replay processor; and
- has a Notifications settings page for reminders and account updates, not incoming-payment capture.

The current backend already parses submitted notification text with Gemini, creates a `receipt` record with `input_type = NOTIFICATION`, and returns it through history/recent endpoints. It does not yet provide background-device credentials, automatic-capture metadata, idempotent notification ingestion, or a reliable way to distinguish a real expense from an unrelated notification.

The older Kotlin app contains a useful listener prototype, but it is not sufficient as the production design because it directly uploads every matched notification without a durable encrypted queue, explicit duplicate protection, or the privacy and device-credential controls required here.

## 3. Problem statement

Users receive transaction notifications from wallets and banks but must currently re-enter or paste those transactions into Broke.AI. This causes missed expenses, delayed tracking, and incomplete monthly history.

A payment notification may be reposted, updated, or delivered while the app is not visible or the device is offline. Therefore, simply calling the existing API from a listener is not sufficient: the solution must be opt-in, durable, secure, idempotent, and able to ignore non-expense notifications.

## 4. Goals and success criteria

### Goals

- Capture supported Android payment notifications after explicit user consent.
- Add a valid captured expense to history without opening Broke.AI.
- Avoid duplicate transactions when Android reposts a notification or a request is retried.
- Preserve captures while offline and retry them safely.
- Make captured transactions identifiable and editable in history.
- Minimize collection and retention of notification content.
- Keep manual entry and pasted-notification processing fully functional.

### Initial success metrics

- At least 95% of eligible test notifications reach a terminal state (`SAVED`, `IGNORED`, or user-action-required) within 60 seconds while online.
- Zero duplicate transactions for the same `captureId`, including concurrent retries.
- At least 90% precision on the approved notification fixture set; unrelated notifications must not be recorded as expenses.
- Zero raw notification bodies stored in the backend database, application logs, analytics, or crash reports.
- Disabling the feature or revoking Notification Access stops new captures immediately.

Metrics must contain only non-sensitive operational data such as result status, source-package identifier, latency bucket, and error code. They must not contain notification title, body, merchant, amount, account number, or payment reference.

## 5. Non-goals

- Reading SMS messages directly through SMS permissions.
- Reading email, accessibility content, or notification history that is no longer active.
- Supporting iOS automatic notification capture.
- Capturing notifications from every installed app.
- Automatically confirming AI-created transactions. Captured transactions remain `PENDING` until reviewed or edited under the existing validation model.
- Retroactively importing dismissed notifications.
- Removing manual expense entry or manual notification-text processing.

## 6. Product requirements

### 6.1 Eligibility

- Automatic capture is available only on Android.
- For the MVP, automatic capture is available only to registered, signed-in users. Guests retain manual entry and their existing limited AI trials.
- The feature is off by default for every user and every device.
- Enabling it on one device must not silently enable it on another device.

### 6.2 Consent and setup

The user flow is:

1. Open **Profile → Notifications → Automatic expense capture**.
2. Read a prominent disclosure explaining:
   - Broke.AI will be able to read notifications while access is enabled;
   - only notifications from apps selected by the user are eligible for processing;
   - eligible notification text is sent to the Broke.AI backend and its disclosed AI processor to extract expense data;
   - raw notification text is deleted from the local queue after success and is not retained in the backend database;
   - access can be revoked at any time; and
   - manual entry remains available if access is declined.
3. Explicitly accept the disclosure.
4. Open Android Notification Access settings and grant access to Broke.AI.
5. Select supported source apps.
6. See a final enabled state and an optional test-notification check.

The app cannot grant Notification Access itself. It must deep-link to Android settings, return to the app, and re-check the actual system permission state. Declining permission must not block other app functionality.

### 6.3 Supported sources

The first supported-package allowlist is:

- Gojek/GoPay: `com.gojek.app`
- OVO: `ovo.id`
- DANA: `id.dana`
- BCA mobile: `com.bca`
- myBCA: `com.bca.mybca.omni.android`
- BNI: `com.bni`
- BRImo: `id.co.bri.brimo`

Engineering must verify current production package identifiers before release. The listener must ignore all packages not enabled by the user. It must also ignore Broke.AI's own notifications.

The source selection is device-local. The UI may show a source as unavailable when the corresponding app is not installed, but implementation must use targeted package queries only and must not request broad `QUERY_ALL_PACKAGES` access.

### 6.4 Capture and classification

For an eligible notification, the Android listener extracts only:

- source package;
- Android notification key;
- posted timestamp;
- title;
- text;
- big text; and
- app-generated `captureId` UUID.

It combines non-empty distinct text fields, trims them, and rejects an empty or oversized payload. A local deterministic pre-filter should reject obviously unrelated notifications before upload. The backend remains authoritative and must classify the payload as an expense or non-expense before creating a transaction.

The AI response contract must add:

- `isExpense` (required boolean);
- `confidence` (0.0–1.0);
- existing date, time, amount, category, payment method, and description fields.

A transaction is saved only when `isExpense = true`, the amount is positive, required output fields pass validation, and the confidence is at or above a server-configured threshold. Otherwise, the result is `IGNORED` or `NEEDS_REVIEW`; it must not silently create a questionable expense.

### 6.5 Durable delivery

The native Android layer must enqueue eligible captures before attempting network delivery. Queue payloads must be encrypted with an Android Keystore-backed key. Do not store raw notification bodies in SharedPreferences.

Use WorkManager for network-constrained delivery and exponential-backoff retry. Each capture must retain the same `captureId` across retries. Successful or ignored queue entries are deleted. Terminal failures retain only a user-visible failure reason and non-sensitive metadata. Pending encrypted payloads expire after seven days, and the queue is capped at 100 items.

Retry behavior:

- network error, timeout, HTTP 429, or HTTP 5xx: retry with backoff;
- expired/revoked capture credential: pause delivery and show **Open Broke.AI to reconnect**;
- HTTP 4xx invalid payload: mark terminal and do not retry;
- duplicate result: delete the local queue entry without adding another transaction.

### 6.6 User feedback

The Automatic expense capture settings section must show:

- platform availability;
- enabled/disabled state;
- Android Notification Access state;
- selected source apps;
- pending queue count;
- last successful capture time; and
- reconnect or retry action when required.

History and recent-activity rows created through this feature must display an **Auto-captured** or equivalent source badge. The transaction remains editable and deletable using the existing history actions.

The app should post a Broke.AI confirmation notification after a transaction is saved only if the user separately permits app notifications. This confirmation must not expose sensitive details on the lock screen by default.

## 7. Technical design

### 7.1 End-to-end flow

```text
Supported wallet/bank notification
              ↓
Android NotificationListenerService
              ↓ filter + deduplicate
Encrypted local capture queue
              ↓ WorkManager when online
Authenticated notification-ingestion API
              ↓ classify + extract + validate
Idempotent transaction save
              ↓
History / Recent / Summary
```

### 7.2 Frontend changes (`broke-ai-app-v2`, `develop` only)

#### Android native layer

- Add `WalletNotificationListenerService.kt` under the existing Android package.
- Declare the service in `android/app/src/main/AndroidManifest.xml` with:
  - `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`;
  - `android.service.notification.NotificationListenerService` intent action;
  - `android:exported="false"`.
- Add a method channel such as `broke.ai/notification_capture` for Flutter to:
  - query actual access state;
  - open listener-detail settings, with a guarded fallback to general listener settings;
  - save enabled source packages;
  - provision/revoke the device capture credential;
  - read queue status; and
  - clear local secrets and queued payloads on logout/account deletion.
- Add an encrypted local queue. Recommended implementation: Room for queue metadata with notification text encrypted using AES-GCM and an Android Keystore-backed key.
- Add WorkManager with a network constraint, unique work names, and exponential backoff.
- Add a debug-only notification fixture path or a separate fixture APK. Debug sources must never be included in the release allowlist.

#### Flutter layer

- Add an Android-only `NotificationCaptureService` abstraction over the method channel.
- Extend the Notifications settings page with Automatic expense capture setup, disclosure, permission status, source selection, and queue status.
- Re-check access in `AppLifecycleState.resumed`, because the user grants or revokes access outside the app.
- Synchronize device-capture setup after login and revoke/clear it during logout, guest-account deletion, registered-account deletion, and session invalidation.
- Extend the transaction model/UI to render `captureMode` and source metadata without exposing raw notification text.
- Replace the current write-only `offline_queue` behavior with a real replay mechanism for manual pasted notifications, or migrate those items into the same reliable queue abstraction.
- Preserve the existing manual `notification(text)` API behavior for non-Android platforms and users who do not opt in.

### 7.3 Backend changes (`broke-ai`, `develop` only)

#### Device-scoped credential

A full user bearer token should not be copied into long-running background components. Add a random, revocable, device-scoped capture credential that authorizes only automatic notification ingestion.

Proposed endpoints:

- `POST /api/v1/me/notification-capture-devices`
  - standard bearer authentication;
  - registers or updates the Android device;
  - returns the device ID and one-time plaintext capture credential;
  - stores only the credential hash.
- `DELETE /api/v1/me/notification-capture-devices/{deviceId}`
  - standard bearer authentication;
  - revokes the capture credential.
- `POST /api/v1/expense/notification`
  - remains backward-compatible with the current `{ "text": "..." }` bearer-authenticated manual request;
  - also accepts the enriched automatic-capture request using the scoped capture credential.

Proposed automatic request:

```json
{
  "text": "Pembayaran Rp75.000 ke GRAB berhasil",
  "captureId": "44368a3b-3ab6-4b11-af63-6c37d735a14e",
  "captureMode": "AUTOMATIC",
  "sourcePackage": "com.gojek.app",
  "notificationPostedAt": "2026-08-24T10:15:30Z"
}
```

Proposed response contract:

```json
{
  "status": "SAVED",
  "transaction": {},
  "captureId": "44368a3b-3ab6-4b11-af63-6c37d735a14e"
}
```

Supported statuses are `SAVED`, `IGNORED`, `DUPLICATE`, and `NEEDS_REVIEW`. Existing manual clients may continue receiving the current transaction response until a versioned migration is completed.

#### Ingestion behavior

- Authenticate the device capture credential and resolve its active user/device.
- Reject credentials that are revoked, belong to a deleted/suspended account, or are not registered for Android.
- Validate maximum payload length, timestamps, UUIDs, capture mode, and source package.
- Deduplicate before invoking Gemini whenever possible to avoid duplicate transactions and duplicate AI cost.
- Make the idempotency check and transaction/capture metadata write concurrency-safe.
- Update the Gemini prompt and DTO for `isExpense` and `confidence`.
- Never log the request body, AI prompt, extracted raw text, account numbers, or transaction references.
- Continue using `inputType = NOTIFICATION`; set `captureMode = AUTOMATIC` for listener-created entries and `PASTED` for manual text.
- Use a separate automatic-capture rate-limit bucket sized for legitimate transaction traffic. Rate limiting must happen after cheap credential and duplicate checks but before the AI call.
- Mark user sync state changed after a successful save, as the current service already does.
- Add structured, non-sensitive error codes so WorkManager can distinguish retryable and terminal failures.

### 7.4 Database changes (`broke-ai`, Flyway migration on `develop` only)

Create the next sequential Flyway migration; do not modify an already-applied migration.

Extend `user_devices` with:

- `notification_capture_token_hash TEXT`;
- `notification_capture_enabled_at TIMESTAMPTZ`;
- `notification_capture_revoked_at TIMESTAMPTZ`;
- `notification_capture_last_used_at TIMESTAMPTZ`.

Add a unique partial index on the non-null credential hash. Store only a SHA-256 or stronger one-way hash of a cryptographically random credential. The plaintext credential is returned only once.

Extend `receipt` with:

- `capture_id UUID`;
- `capture_mode VARCHAR(20)` with allowed values `AUTOMATIC` and `PASTED` when `input_type = NOTIFICATION`;
- `capture_device_id UUID` referencing `user_devices(id)` with `ON DELETE SET NULL`;
- `source_package VARCHAR(255)`;
- `source_notification_posted_at TIMESTAMPTZ`;
- `source_payload_hash TEXT`.

Add a unique partial index on `(user_id, capture_id)` where `capture_id IS NOT NULL` and `deleted_at IS NULL`. Also use the existing `idempotency_records` infrastructure for request replay and concurrent delivery.

Do **not** add a raw notification body/title column. The backend may hold notification text only in memory for request validation and AI processing. The transaction table stores only the extracted expense fields and non-sensitive capture metadata.

Migration verification must cover both a clean database and an upgrade from the current `develop` schema with existing receipt rows.

## 8. Security, privacy, and compliance requirements

- Notification Access must be preceded by a prominent in-app disclosure and affirmative consent.
- Access only notifications from user-selected supported packages.
- Do not use notification content for advertising, unrelated analytics, or model training.
- Disclose the AI processor and data purpose in the privacy policy and Play Data safety form.
- Use TLS in every non-local environment. Automatic capture must not be released against the current cleartext HTTP production base URL.
- Store the device capture credential and local encryption key using Android Keystore-backed storage.
- Revoke the device credential on logout, device removal, account deletion, or capture disablement.
- Clear local queued notification content on logout/account deletion and when it reaches retention limits.
- Mask sensitive data in debug output and disable request-body logging for this endpoint in every build type.
- Conduct a Google Play policy review before any store submission; notification content and financial/payment information are sensitive user data.

## 9. Testing plan

### 9.1 Backend automated tests

- Controller tests for legacy manual requests and enriched automatic requests.
- Authentication tests for valid, missing, malformed, expired/revoked, cross-user, and suspended-user capture credentials.
- Validation tests for blank/oversized text, unknown package, malformed UUID, and unreasonable timestamps.
- Service tests for expense, non-expense, low-confidence, incomplete AI output, Gemini timeout, and malformed Gemini JSON.
- Idempotency tests proving repeated and concurrent requests with the same `captureId` create exactly one transaction and invoke Gemini at most once after the idempotency record exists.
- Rate-limit tests for automatic and manual traffic.
- Repository tests for source metadata and active-history queries.
- Flyway tests for clean install, upgrade with existing data, rollback strategy validation, constraints, and indexes.
- Privacy tests/assertions ensuring raw notification text is absent from persisted entities and captured logs.

Run at minimum:

```bash
./mvnw test
```

### 9.2 Flutter and Android automated tests

- Dart unit tests for platform eligibility, setup state, permission-state mapping, source selection, and API result mapping.
- Flutter widget tests for disclosure, declined access, enabled state, revoked state, queue errors, and non-Android UI.
- Kotlin unit tests for supported-package filtering, text extraction, normalization, empty/oversized rejection, fingerprinting, and queue retention.
- WorkManager tests using the Android WorkManager test library for success, retry, terminal failure, expired credential, and duplicate response.
- HTTP tests using MockWebServer to verify headers, JSON, retry classification, and that secrets/content are not logged.
- Method-channel contract tests between Flutter and Kotlin.
- Regression tests for pasted notification text, receipt scanning, manual expense creation, logout, account deletion, history refresh, and guest trial behavior.

Run at minimum:

```bash
flutter analyze
flutter test
cd android && ./gradlew test
```

### 9.3 Manual device test setup

Use a physical Android device for acceptance testing because Notification Access and listener lifecycle behavior are not fully represented by Flutter widget tests.

Create a small debug-only notification fixture APK with a non-production package name. Include that package only in debug builds. The fixture must be able to post:

- a valid GoPay-style expense;
- a valid bank-transfer expense;
- an unrelated promotional notification;
- a notification with no amount;
- a duplicate/reposted notification; and
- an updated notification using the same key.

Manual happy-path procedure:

1. Check out `develop` in both repositories and deploy the backend/database to a development environment.
2. Install a debug frontend build and the fixture APK.
3. Sign in with a registered development account.
4. Open Automatic expense capture, accept the disclosure, and grant Notification Access.
5. Enable the fixture source.
6. Background Broke.AI and post a valid fixture notification.
7. Confirm the transaction appears in Recent and History within 60 seconds with `inputType = NOTIFICATION`, `captureMode = AUTOMATIC`, correct fields, and `PENDING` validation.
8. Edit and delete the transaction to verify existing actions still work.
9. Verify database metadata and confirm that raw notification text was not persisted.

### 9.4 Manual failure and lifecycle matrix

Verify all of the following on at least Android 10, Android 13, and the current target Android version, using Pixel plus at least one OEM device with aggressive battery management:

- app visible, backgrounded, swiped from recents, screen locked, and after device reboot;
- Wi-Fi/mobile data online, offline then restored, timeout, server 500, and server 429;
- Notification Access denied, granted, and revoked while the app is backgrounded;
- feature disabled while access remains granted;
- unselected package, selected package, and Broke.AI's own package;
- duplicate/reposted notification and concurrent WorkManager retry;
- expired/revoked device credential followed by reconnect;
- logout, session invalidation, password change/session revocation, and account deletion;
- queue cap and seven-day expiration;
- general marketing notification, OTP, balance update, incoming transfer, refund, failed payment, and successful expense;
- lock-screen confirmation privacy; and
- device locale/time-zone changes.

### 9.5 Acceptance criteria

The feature is ready for internal release on `develop` when:

- a registered user can opt in and Android shows Broke.AI as an enabled notification listener;
- a supported valid payment notification creates one and only one pending transaction while Broke.AI is not visible;
- unrelated, unsupported, duplicate, and low-confidence notifications do not create expenses;
- offline captures upload after connectivity returns without user re-entry;
- revoking access or disabling capture stops new ingestion;
- logout/account deletion clears local secrets and pending sensitive payloads;
- existing manual, receipt, history, summary, recent, guest, and account flows pass regression tests;
- no raw notification content appears in backend persistence or logs;
- the privacy disclosure, privacy policy, and Play Data safety information have been reviewed; and
- all code, migrations, and tests remain only on `develop`, with PR base branches verified before merge.

## 10. Rollout plan

1. Backend schema, credential, idempotency, and classification work on `develop` behind a disabled server feature flag.
2. Android listener, queue, WorkManager, and Flutter setup UI on `develop` behind a debug/internal flag.
3. Automated and fixture-based integration testing against the development backend.
4. Internal Android build for a small allowlisted tester group.
5. Tune source filters and confidence threshold using synthetic/consented test fixtures only.
6. Complete privacy and Google Play policy review.
7. Product owner decides separately whether and when the completed `develop` work may be promoted. Promotion to `master` or production is explicitly outside this PRD's authorized scope.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Sensitive notifications are over-collected | Explicit opt-in, per-app allowlist, local pre-filter, no broad package visibility, short retention |
| Duplicate Android posts create duplicate expenses | Stable `captureId`, local fingerprinting, backend unique index, idempotency records |
| AI treats promotions or balance alerts as expenses | `isExpense` and confidence contract, deterministic validation, fixture test corpus, `NEEDS_REVIEW` state |
| App process/network is unavailable | Encrypted queue plus WorkManager retry |
| Background auth exposes the full user session | Random scoped device credential stored hashed server-side and Keystore-backed client-side |
| Token/session is revoked | Pause queue, require reconnect, revoke credential on lifecycle events |
| Google Play rejection or user mistrust | Prominent disclosure, core-feature justification, privacy policy/Data safety updates, manual alternative |
| OEM battery restrictions delay work | WorkManager, device matrix, visible queue status, OEM guidance only when necessary |
| AI cost increases from noisy notifications | Source allowlist, local/server pre-filters, dedupe before AI, separate rate limits |

## 12. Dependencies and open decisions

Before implementation begins, product and engineering must confirm:

- whether guests remain excluded from automatic capture after MVP;
- the supported package IDs and representative notification formats;
- the AI confidence threshold and handling of refunds/incoming transfers;
- whether `NEEDS_REVIEW` creates a draft transaction or only a capture-status item;
- local encrypted-queue library choices and minimum Android SDK compatibility;
- scoped credential expiration/rotation period;
- development HTTPS endpoint and certificate configuration;
- final consent and privacy-policy wording; and
- whether a Broke.AI confirmation notification is enabled by default or opt-in.

## 13. Reference material

- [Android NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
- [Android notification-listener settings actions](https://developer.android.com/reference/android/provider/Settings#ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
- [Android persistent background work with WorkManager](https://developer.android.com/develop/background-work/background-tasks/persistent)
- [Google Play permissions and sensitive-information policy](https://support.google.com/googleplay/android-developer/answer/16558241)
- [Google Play prominent disclosure and consent guidance](https://support.google.com/googleplay/android-developer/answer/11150561)
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)

