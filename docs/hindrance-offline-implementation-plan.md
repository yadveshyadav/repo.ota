# Hindrance offline implementation plan

## Objective

Let a signed-in user prepare and save Hindrance and related CCN reports offline using only task data that the backend authorizes for that account. Keep drafts and captured evidence available after app restarts, then synchronize queued reports safely when connectivity and the submission API contract are available.

## Implementation status

- Implemented in the current app: paged task reads, account-scoped local task snapshots, Block → Ring → Segment selection, the Hindrance hierarchy/table presentation, and Hindrance create/save/submit calls using the supplied task-service contract.
- Hindrance submission requires approved-plan metadata on the selected Block. It saves the server-created merged task ID locally before continuing so a retry reuses that task.
- Remaining contract work: confirm the photo-upload URL version; define upload behavior for video and SHP evidence; finalize Hindrance/CCN field data; and connect CCN submission. Missing plan metadata is surfaced before task creation instead of guessed.

## Evidence and current behavior

- The provided API capture shows `GET /api/tasks/my-tasks/type-counts` and a paginated `GET /api/tasks/my-tasks` response. The example list response has `pageSize: 10`, `totalElements: 17238`, and task records with IDs, task level/parent references, location, route snapshots, and assignee/approval information. Type counts are aggregate counts and are not a task list.
- The provided `GET /api/master/data` response contains a large nationwide hierarchy of companies, circles, districts, blocks, and locations. Its full response is much larger than the data needed for one selected task.
- `HindranceTaskDataSource` fetches pages at size 100, capped at 20 pages, then replaces the whole account snapshot. It has no explicit selected-task filter or account-identity check against each returned task. Failed requests fall back to the local snapshot.
- `HindranceLocalStore` stores task JSON by `(owner_id, task_id)` and reports by `(owner_id, report_id)`. Reports and media are saved locally; media bytes are held in IndexedDB on web and app files on native platforms.
- Hindrance uses cached task levels and embedded route/segment snapshots to build Block → Ring → Segment choices. CCN categories and subtypes are currently hardcoded in `ccn_catalog.dart`.
- Hindrance photo upload uses the supplied `/api/survey/v2/photo-upload-url` path. The photo endpoint version remains unconfirmed; video and SHP evidence are retained locally and block submission because no upload contract was supplied for them.
- CCN is still saved locally and is not sent to task-service. The Hindrance field contract is provisional, so backend validation may still require adjustments when the final field list is confirmed.
- The task API service currently tries `/api/v1/integrations/tasks/...` and `/api/v1/tasks/...`, while the supplied capture names `/api/tasks/...`; the configured default base URL is also different from the supplied UAT host. Confirm deployment configuration and the actual successful request before changing endpoints.
- The worktree already contains uncommitted changes, including the Hindrance feature. Preserve those changes while implementing this plan.

## Target behavior

1. A user can choose or open a task only from the authenticated account's authorized `my-tasks` results.
2. “Make available offline” downloads the selected task plus the minimum hierarchy and metadata needed by Hindrance: its Block, descendant Rings, Segments, and route/segment snapshots. It does not download another user's task data or the complete nationwide master-data catalog.
3. Offline Hindrance can create, edit, resume, and review a report and optional linked CCN, including all evidence and KML artifacts, without losing data on restart.
4. The UI clearly distinguishes locally saved work from work accepted by the server. A queued item is never shown as synced until the server acknowledges it.
5. On reconnection, the app uploads the report and its evidence in a retryable, idempotent way, handles partial failures, and retains local data until confirmed success.

## Implementation phases

### 1. Confirm API and access contract

- Reproduce the successful UAT requests from the captures using an authorized development account; do not use the pasted credentials in source code, logs, or fixtures.
- Confirm the exact base URL and route version for `my-tasks`, task detail, `master/data`, Hindrance submit, CCN submit, and media upload. Record required query parameters, pagination semantics, response envelopes, and authorization behavior.
- Confirm whether `my-tasks` means assigned tasks only or also tasks where the user is creator/approver. Treat the backend response as the authority; do not invent client-side role rules.
- Ask the backend/API owner for supported filters (user, task ID, block/ring, location) and a bounded response contract for master data. If the API is user-scoped already, retain that as the authorization boundary and validate returned identifiers against the signed-in user only where the contract makes that relationship explicit.

### 2. Define an offline task-pack contract

- Model an offline pack with `ownerId`, selected root task ID, fetched task IDs, schema version, fetched timestamp, and server revision/ETag if available.
- Resolve the selected task's hierarchy using the authorized task list and/or task-detail endpoint. Prefer server-side task-ID/ancestor filters; otherwise fetch pages only until pagination is complete and impose a documented limit with a visible incomplete-download state. Do not silently treat the existing 2,000-record cap as complete.
- Store only fields needed for the Hindrance selection and evidence context. Preserve authoritative IDs, hierarchy, location, coordinates, route snapshots, and segment definitions; avoid persisting unrelated task execution or large payloads.
- Download master data only when a screen actually needs fields absent from the selected task pack. Prefer a task/location-scoped endpoint or requested subset. Do not cache the full `/api/master/data` response by default.

### 3. Harden account-scoped persistence

- Keep every task-pack, report, and media read/write scoped by the authenticated stable user ID, not phone number or display name.
- On account switch/logout, ensure one user's offline pack and reports cannot be displayed under another account. Retain or clear prior-account data according to the product's offline-retention policy; never reassign it to the next account.
- Add schema migration/indexes for pack metadata and sync state. Make pack replacement transactional so a failed or partial download does not erase the last valid offline pack.
- Avoid making task API calls when there is no valid authenticated account; offline access should use the matching account's cached data and respect session/access policy.

### 4. Make the Hindrance and CCN workflow reliably offline

- Bind a report to the selected task-pack ID and validate that the Block, Ring, and selected Segments all belong to that pack before saving.
- Preserve current draft autosave behavior, but make state transitions explicit: `LOCAL_DRAFT`, `READY_TO_SYNC`, `SYNCING`, `SYNC_FAILED`, and `SYNCED` (or equivalent agreed names). Store attempt count, last attempt/error, and server IDs separately from the user-editable payload.
- Verify that every media record resolves to durable bytes/file storage, including after app restart and on web. Track evidence references in the report and protect against orphaned or prematurely deleted media.
- Keep CCN categories locally available for offline use until a versioned CCN catalog API is confirmed. If categories become server-managed, cache a versioned minimal catalog and define behavior when it is stale.
- Confirm whether photo/video GPS stamping, video duration rules, and KML generation match backend requirements before upload is implemented.

### 5. Implement synchronization after API contract confirmation

- Add a repository/service dedicated to Hindrance and CCN submission rather than placing HTTP calls in widgets.
- Upload in dependency order (Hindrance first when CCN references it, then CCN and media as the contract requires). Use stable client-generated idempotency IDs so retries cannot create duplicate reports.
- Retry transient network/server errors with bounded backoff; treat validation/auth errors as actionable and keep the item and evidence locally.
- Update `SYNCED` only from a successful server response. Keep user-visible retry and conflict-resolution behavior, and prevent edits from being overwritten while a sync is in progress.
- Retain local records until all dependent uploads are acknowledged and the chosen retention policy allows cleanup.

### 6. UX and observability

- Show the selected task pack's last download time, available offline status, and a clear download/refresh action.
- Explain when a task hierarchy is incomplete or unavailable offline. Do not show sample data as a fallback.
- Show pending, syncing, failed, and synced report states with a retry action. Keep server errors actionable without exposing tokens or sensitive response bodies.
- Log request route, page, counts, duration, and outcome in debug-safe telemetry; exclude credentials, full report payloads, and sensitive media.

## Acceptance criteria

- User A can download a specific authorized task hierarchy, enable airplane mode, restart the app, and create/resume Hindrance and CCN drafts against that task.
- User B cannot read User A's task pack, reports, or media after account switch, including through stale in-memory state.
- The offline download is complete or explicitly marked incomplete; pagination limits cannot silently produce a falsely complete pack.
- A large `my-tasks` total does not cause the app to cache the entire organization dataset, and task type counts are never treated as task records.
- Hindrance/CCN remain marked pending/failed until the API acknowledges submission; retries do not create duplicate server records.
- Interrupted downloads, app termination during capture, network loss during upload, and partial media upload preserve recoverable local state.

## Suggested delivery order

1. API contract and account-scope verification.
2. Offline task-pack schema, transactional download, and account-switch isolation.
3. Hindrance/CCN draft and media durability using the pack.
4. Submission API integration and idempotent sync.
5. Offline, pagination, account-isolation, migration, and retry validation on Android, iOS, and web where supported.

## Open decisions

- Which task should be downloaded: user-selected task, current task opened from the task list, or an explicit list of assigned tasks?
- Does the backend expose selected-task/descendant filters and sync/submit endpoints for Hindrance and CCN?
- Should cached data remain after logout for the same returning account, or be erased on logout?
- What storage budget and retention period should apply to offline video and report evidence?
